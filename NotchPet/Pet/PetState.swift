import Foundation
import Combine

extension Notification.Name {
    /// Posted whenever the pet transitions into `.departed`. The panel
    /// controller observes this to trigger a heavy shake animation.
    static let notchPetDidDepart = Notification.Name("notchPetDidDepart")
}

/// Transient enum describing a brief feedback animation that plays on
/// the pet sprite after a care action. Auto-cleared after ~900ms.
enum ActionAnimation: Equatable {
    case eating
    case playing
    case medicine
    case pooping
    case cleaning
}

/// Behavioral state of the pet. Drives movement + ambient animations.
enum PetBehavior: Equatable {
    case idle
    case walking(targetX: CGFloat)
    case performing(PetMode)
    case actionFeedback(PetMode)
}

/// The gameplay state of the pet. Block 6 switches the vital meters from
/// continuous 0–1 floats to discrete 0–4 integer hearts (Tamagotchi
/// convention), deletes the `energy`/`rest` loop in favour of purely
/// scheduled sleep, and adds sickness + poop maintenance beats.
@MainActor
final class PetState: ObservableObject {
    // Identity / generation
    @Published var id: UUID
    @Published var name: String
    @Published var bornAt: Date
    @Published var generation: Int
    @Published var species: Species

    // Vitals — Block 6 discrete hearts, each 0...Self.maxHearts (4)
    @Published var hunger: Int
    @Published var happy: Int
    @Published var weight: Int

    // Runtime flags
    @Published var isAsleep: Bool
    @Published var lastTickAt: Date

    /// Transient: set by `feed/play` for 4s so the pet briefly shows the
    /// `.happy` sprite mode (Block 4 behaviour).
    @Published var happyUntil: Date? = nil

    /// Transient hover state. Drives `.curious` mode.
    @Published var isHovered: Bool = false

    /// Set after the departed grace period expires. The pet lingers
    /// until the user taps "Welcome New Life" in the reborn overlay.
    @Published var awaitingRebornConfirm: Bool = false

    // Movement + behavior (transient, not persisted)
    @Published var petX: CGFloat = 0
    @Published var facingRight: Bool = true
    @Published var activeBehavior: PetBehavior = .idle

    /// Transient feed-rejection marker (aloof personality).
    @Published var feedRejectedUntil: Date? = nil

    /// Transient action-animation state (Block 6). Cleared by a
    /// scheduled main-queue job 0.9s after set.
    @Published var actionAnimation: ActionAnimation? = nil

    // Sickness (Block 6)
    @Published var sick: Bool
    @Published var medicineDosesRemaining: Int
    /// When the next stage-based sickness roll should fire. Scheduled on
    /// entering adult / elder.
    @Published var sicknessCheckDueAt: Date?

    // Poop (Block 6)
    @Published var poops: Int
    /// Earliest time at which the current pile began accumulating —
    /// used by the sickness rule "poop sitting too long".
    @Published var lastPoopAt: Date?
    /// When the next poop should spawn. Set by `feed()`.
    @Published var poopDueAt: Date?

    // Lifecycle
    @Published var ageActiveSeconds: Double
    @Published var stage: LifecycleStage
    @Published var departedAt: Date?

    // Elder neglect trackers — how long each critical condition has persisted
    @Published var elderHungerZeroSeconds: Double
    @Published var elderHappyZeroSeconds: Double
    @Published var elderSickSeconds: Double

    // Personality
    @Published var personality: PersonalityTrait?
    @Published var careHistory: CareHistory

    // Private decay accumulators (not persisted)
    private var hungerDecayAccum: Double = 0
    private var happyDecayAccum: Double = 0
    /// How long the vitals have been at zero since the last tick. Used
    /// by the neglect sickness trigger.
    private var neglectSeconds: Double = 0

    /// Injected by `AppDelegate` so coin earning flows to `PlayerInventory`
    /// without `PetState` having to know about the inventory type.
    var onCoinsEarned: ((Int) -> Void)?

    // MARK: - Constants
    //
    // nonisolated so they can be referenced from default-parameter
    // expressions in `init`, which run outside the main-actor context.

    nonisolated static let maxHearts: Int = 4
    nonisolated static let initialHunger: Int = 3
    nonisolated static let initialHappy: Int = 3
    nonisolated static let initialWeight: Int = 10
    nonisolated static let minWeight: Int = 5

    init(
        id: UUID = UUID(),
        name: String = "ひよこ",
        bornAt: Date = Date(),
        generation: Int = 1,
        species: Species = .chick,
        hunger: Int = PetState.initialHunger,
        happy: Int = PetState.initialHappy,
        weight: Int = PetState.initialWeight,
        isAsleep: Bool = false,
        lastTickAt: Date = Date(),
        sick: Bool = false,
        medicineDosesRemaining: Int = 0,
        sicknessCheckDueAt: Date? = nil,
        poops: Int = 0,
        lastPoopAt: Date? = nil,
        poopDueAt: Date? = nil,
        ageActiveSeconds: Double = 0,
        stage: LifecycleStage = .egg,
        departedAt: Date? = nil,
        elderHungerZeroSeconds: Double = 0,
        elderHappyZeroSeconds: Double = 0,
        elderSickSeconds: Double = 0,
        personality: PersonalityTrait? = nil,
        careHistory: CareHistory = CareHistory()
    ) {
        self.id = id
        self.name = name
        self.bornAt = bornAt
        self.generation = generation
        self.species = species
        self.hunger = hunger
        self.happy = happy
        self.weight = weight
        self.isAsleep = isAsleep
        self.lastTickAt = lastTickAt
        self.sick = sick
        self.medicineDosesRemaining = medicineDosesRemaining
        self.sicknessCheckDueAt = sicknessCheckDueAt
        self.poops = poops
        self.lastPoopAt = lastPoopAt
        self.poopDueAt = poopDueAt
        self.ageActiveSeconds = ageActiveSeconds
        self.stage = stage
        self.departedAt = departedAt
        self.elderHungerZeroSeconds = elderHungerZeroSeconds
        self.elderHappyZeroSeconds = elderHappyZeroSeconds
        self.elderSickSeconds = elderSickSeconds
        self.personality = personality
        self.careHistory = careHistory
    }

    var ageDays: Double {
        ageActiveSeconds / LifecycleClock.activeSecondsPerDay
    }

    // MARK: - Derived state

    var canInteract: Bool {
        !isAsleep && stage != .egg && stage != .departed
    }

    /// Temporary post-interaction mood boost (transient; see `.happy` mode).
    var isHappy: Bool {
        guard let until = happyUntil else { return false }
        return until > Date()
    }

    // MARK: - Actions

    func feed() {
        guard canInteract else { return }
        // Aloof pets refuse feeding ~20% of the time.
        let acceptProbability = personality?.feedAcceptProbability ?? 1.0
        if acceptProbability < 1.0, Double.random(in: 0..<1) >= acceptProbability {
            feedRejectedUntil = Date().addingTimeInterval(1.0)
            SoundPlayer.shared.play(.feedReject)
            return
        }
        hunger = min(Self.maxHearts, hunger + 1)
        weight = min(99, weight + 1)
        careHistory.recordFeed()
        happyUntil = Date().addingTimeInterval(Self.happyDuration)
        SoundPlayer.shared.play(.feed)
        triggerActionAnimation(.eating)
        schedulePoopIfNeeded()
        onCoinsEarned?(1)
    }

    func play() {
        guard canInteract else { return }
        happy = min(Self.maxHearts, happy + 1)
        weight = max(Self.minWeight, weight - 1)
        careHistory.recordPlay()
        happyUntil = Date().addingTimeInterval(Self.happyDuration)
        SoundPlayer.shared.play(.play)
        triggerActionAnimation(.playing)
        onCoinsEarned?(1)
    }

    /// Block 6: new action. Administer medicine to clear sickness.
    /// Like classic Tamagotchi, takes two doses. Final dose awards coins.
    func takeMedicine() {
        guard sick, medicineDosesRemaining > 0 else { return }
        medicineDosesRemaining -= 1
        SoundPlayer.shared.play(.medicine)
        triggerActionAnimation(.medicine)
        if medicineDosesRemaining == 0 {
            sick = false
            onCoinsEarned?(3)
        }
    }

    /// Block 6: new action. Sweep away all poops.
    func clean() {
        guard poops > 0 else { return }
        poops = 0
        lastPoopAt = nil
        SoundPlayer.shared.play(.clean)
        triggerActionAnimation(.cleaning)
        onCoinsEarned?(2)
    }

    private func triggerActionAnimation(_ kind: ActionAnimation) {
        actionAnimation = kind
        // Map ActionAnimation → sprite PetMode for behavior engine
        let spriteMode: PetMode
        switch kind {
        case .eating:   spriteMode = .eat
        case .playing:  spriteMode = .playAct
        case .medicine: spriteMode = .medic
        case .pooping:  spriteMode = .poopAct
        case .cleaning: spriteMode = .cleanAct
        }
        activeBehavior = .actionFeedback(spriteMode)

        let deadline = DispatchTime.now() + .milliseconds(900)
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
            guard let self else { return }
            if self.actionAnimation == kind {
                self.actionAnimation = nil
                if case .actionFeedback = self.activeBehavior {
                    self.activeBehavior = .idle
                }
            }
        }
    }

    private func schedulePoopIfNeeded() {
        guard stage == .child || stage == .adult || stage == .elder else { return }
        // Don't stack: if one is already due, leave it.
        if poopDueAt != nil { return }
        poopDueAt = Date().addingTimeInterval(Self.poopDelayActiveSeconds)
    }

    private static let happyDuration: TimeInterval = 4.0

    // MARK: - Decay

    /// Block 6: discrete heart-based decay. A fractional accumulator
    /// advances by active-seconds each tick; when it crosses the per-heart
    /// interval, one heart is deducted. Sleep, egg, departed all pause.
    /// Sickness halves the decay so a sick pet can't death-spiral.
    func applyDecay(activeSeconds: Double) {
        guard activeSeconds > 0, !isAsleep else { return }
        guard stage != .egg && stage != .departed else { return }

        let multiplier = Self.decayMultiplier
        let sicknessMult = sick ? 0.5 : 1.0
        let elderMult = (stage == .elder) ? Self.elderDecayMultiplier : 1.0
        let dt = activeSeconds * multiplier * sicknessMult * elderMult

        // Personality effect: gluttonous hunger empties faster.
        let hungerTraitMult = personality?.hungerDecayMultiplier ?? 1.0

        hungerDecayAccum += dt * hungerTraitMult
        happyDecayAccum += dt

        let hungerInterval = Self.hungerSecondsPerHeart
        while hungerDecayAccum >= hungerInterval, hunger > 0 {
            hunger -= 1
            hungerDecayAccum -= hungerInterval
        }
        if hunger == 0 { hungerDecayAccum = 0 }

        let happyInterval = Self.happySecondsPerHeart
        while happyDecayAccum >= happyInterval, happy > 0 {
            happy -= 1
            happyDecayAccum -= happyInterval
        }
        if happy == 0 { happyDecayAccum = 0 }
    }

    /// Block 6: new per-tick job for poop spawning + sickness triggers.
    /// Kept separate from `applyDecay` for clarity — decay is a pure
    /// function of elapsed time; this is state-machine logic.
    func runCareTick(now: Date, activeSeconds: Double) {
        guard stage == .child || stage == .adult || stage == .elder else { return }
        guard !isAsleep else { return }

        // Scheduled poop spawn
        if let due = poopDueAt, now >= due, poops < 3 {
            poops = min(3, poops + 1)
            if lastPoopAt == nil { lastPoopAt = now }
            poopDueAt = nil
            triggerActionAnimation(.pooping)
        }

        // Neglect timer: accumulates while any vital is at 0
        if hunger == 0 || happy == 0 {
            neglectSeconds += activeSeconds
        } else {
            neglectSeconds = 0
        }

        // Elder-specific death triggers — separate from general neglect→sickness
        if stage == .elder {
            elderHungerZeroSeconds = (hunger == 0) ? elderHungerZeroSeconds + activeSeconds : 0
            elderHappyZeroSeconds  = (happy == 0)  ? elderHappyZeroSeconds + activeSeconds  : 0
            elderSickSeconds       = sick ? elderSickSeconds + activeSeconds : 0

            if elderHungerZeroSeconds >= Self.elderHungerDeathSeconds
                || elderHappyZeroSeconds >= Self.elderHappyDeathSeconds
                || elderSickSeconds >= Self.elderSickDeathSeconds {
                triggerElderDeath()
                return
            }
        }

        // Don't stack multiple illnesses.
        guard !sick else { return }

        // Rule 1: stage-based random sickness. On entering adult / elder,
        // `handleStageTransition` sets `sicknessCheckDueAt` to a random
        // point in that stage. When that time arrives, flip sick with
        // a 40% roll (or skip and let neglect/poop handle it).
        if let due = sicknessCheckDueAt, now >= due {
            sicknessCheckDueAt = nil
            let chance = (stage == .elder) ? Self.elderSicknessChance : 0.40
            if Double.random(in: 0..<1) < chance {
                becomeSick()
                if stage == .elder { scheduleNextElderSicknessCheck() }
                return
            }
            if stage == .elder { scheduleNextElderSicknessCheck() }
        }

        // Rule 2: sustained neglect
        if neglectSeconds >= Self.neglectSecondsToSick {
            becomeSick()
            return
        }

        // Rule 3: poop exposure
        if poops > 0, let firstPoopAt = lastPoopAt,
           now.timeIntervalSince(firstPoopAt) >= Self.poopExposureToSick {
            becomeSick()
            return
        }
    }

    private func becomeSick() {
        sick = true
        medicineDosesRemaining = 2
        neglectSeconds = 0
        SoundPlayer.shared.play(.angry)  // reuse the low-buzz sound as an illness cue
    }

    private func triggerElderDeath() {
        stage = .departed
        handleStageTransition(from: .elder, to: .departed)
    }

    private func scheduleNextElderSicknessCheck() {
        let window = 2.0 * LifecycleClock.activeSecondsPerDay
        let offset = Double.random(in: (0.3 * window)..<window)
        sicknessCheckDueAt = Date().addingTimeInterval(offset)
    }

    /// Advance the lifecycle clock by `activeSeconds` and recompute stage.
    /// Departed is set only by `triggerElderDeath()` — the table doesn't
    /// know about death, so we must not let it overwrite a death transition.
    func advanceLifecycle(activeSeconds: Double, table: LifecycleTable = LifecycleTable()) {
        guard activeSeconds > 0 else { return }
        guard stage != .departed else { return }
        ageActiveSeconds += activeSeconds
        let previous = stage
        let next = table.stage(forAgeDays: ageDays)
        if next != previous {
            stage = next
            handleStageTransition(from: previous, to: next)
        }
    }

    private func handleStageTransition(from old: LifecycleStage, to new: LifecycleStage) {
        if old == .child && new == .adult && personality == nil {
            var rng = SystemRandomNumberGenerator()
            personality = careHistory.derivePersonality(rng: &rng)
        }
        if new == .departed && departedAt == nil {
            departedAt = Date()
        }

        // Lifecycle-transition sound cues
        if old == .egg && new == .child {
            SoundPlayer.shared.play(.hatch)
        }
        if new == .departed {
            SoundPlayer.shared.play(.depart)
            NotificationCenter.default.post(name: .notchPetDidDepart, object: nil)
        }

        // Schedule stage-based sickness roll on entering adult/elder
        if new == .adult, sicknessCheckDueAt == nil {
            let offsetSeconds = Double.random(in: 0..<1) *
                3.0 * LifecycleClock.activeSecondsPerDay
            sicknessCheckDueAt = Date().addingTimeInterval(offsetSeconds)
        }
        if new == .elder, sicknessCheckDueAt == nil {
            scheduleNextElderSicknessCheck()
        }

        // Block 6: lifecycle coin bonus
        if new == .child || new == .adult || new == .elder {
            onCoinsEarned?(10)
        }
        if new == .departed {
            onCoinsEarned?(20)
        }
    }

    /// Called by the UI when the user taps the reborn confirmation button.
    func confirmReborn() {
        guard awaitingRebornConfirm else { return }
        rebornAsNewGeneration()
    }

    /// Reset this state instance to a fresh egg for the next generation.
    func rebornAsNewGeneration() {
        awaitingRebornConfirm = false
        id = UUID()
        species = Species.allCases.randomElement() ?? .chick
        name = "ひよこ"
        bornAt = Date()
        generation += 1
        hunger = Self.initialHunger
        happy = Self.initialHappy
        weight = Self.initialWeight
        isAsleep = false
        lastTickAt = Date()
        sick = false
        medicineDosesRemaining = 0
        sicknessCheckDueAt = nil
        poops = 0
        lastPoopAt = nil
        poopDueAt = nil
        ageActiveSeconds = 0
        stage = .egg
        departedAt = nil
        elderHungerZeroSeconds = 0
        elderHappyZeroSeconds = 0
        elderSickSeconds = 0
        personality = nil
        careHistory.reset()
        hungerDecayAccum = 0
        happyDecayAccum = 0
        neglectSeconds = 0
        petX = 0
        facingRight = true
        activeBehavior = .idle
    }

    // MARK: - Tuning constants

    /// Seconds of active computer time for one heart to drain. DEBUG
    /// builds are dramatically faster so the full care loop is visible
    /// during smoke tests; release builds use real minutes.
    static var hungerSecondsPerHeart: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_HUNGER_SEC"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 20.0   // 20s per heart in debug → 80s to fully starve
        #else
        return 5 * 60.0
        #endif
    }()

    static var happySecondsPerHeart: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_HAPPY_SEC"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 30.0
        #else
        return 8 * 60.0
        #endif
    }()

    /// How long after feeding a poop appears.
    static var poopDelayActiveSeconds: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_POOP_DELAY"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 25.0
        #else
        return 5 * 60.0
        #endif
    }()

    /// Active seconds at 0 hunger/happy before the pet gets sick.
    static var neglectSecondsToSick: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_NEGLECT_SEC"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 15.0
        #else
        return 2 * 60.0
        #endif
    }()

    /// Active seconds that a poop must sit before causing sickness.
    static var poopExposureToSick: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_POOP_SICK_SEC"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 20.0
        #else
        return 3 * 60.0
        #endif
    }()

    /// Global DEBUG speedup — still applied as a final multiplier on
    /// top of the per-stat intervals above.
    private static var decayMultiplier: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_DECAY_SPEEDUP"],
           let value = Double(raw), value > 0 {
            return value
        }
        #if DEBUG
        return 1.0
        #else
        return 1.0
        #endif
    }()

    // MARK: - Elder fragility constants

    static let elderDecayMultiplier: Double = 1.5
    static let elderSicknessChance: Double = 0.60

    static var elderHungerDeathSeconds: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_ELDER_HUNGER_DEATH"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 10.0   // 0.5 debug-days
        #else
        return 0.5 * 86_400.0
        #endif
    }()

    static var elderHappyDeathSeconds: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_ELDER_HAPPY_DEATH"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 20.0   // 1.0 debug-day
        #else
        return 86_400.0
        #endif
    }()

    static var elderSickDeathSeconds: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_ELDER_SICK_DEATH"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 20.0   // 1.0 debug-day
        #else
        return 86_400.0
        #endif
    }()
}
