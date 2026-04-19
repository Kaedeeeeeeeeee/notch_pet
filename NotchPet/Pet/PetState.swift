import Foundation
import Combine

extension Notification.Name {
    /// Posted whenever the pet transitions into `.departed`. The panel
    /// controller observes this to trigger a heavy shake animation.
    static let notchPetDidDepart = Notification.Name("notchPetDidDepart")
}

/// A single poop pile dropped on the room floor. Each pile remembers
/// the `petX` at the moment of spawn so it stays put instead of
/// tracking the pet around.
struct PoopPile: Codable, Identifiable, Equatable {
    let id: UUID
    let xOffset: CGFloat

    init(id: UUID = UUID(), xOffset: CGFloat) {
        self.id = id
        self.xOffset = xOffset
    }
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
    @Published var petY: CGFloat = 0
    @Published var facingRight: Bool = true
    @Published var activeBehavior: PetBehavior = .idle

    /// True while the user is dragging the pet around the room. Suspends
    /// `PetBehaviorEngine` ticks and forces the `.held` sprite mode.
    @Published var isBeingHeld: Bool = false

    /// Short window after a tap reaction during which the room cursor
    /// shows the "petting hand" variant. Transient.
    @Published var tapReactionUntil: Date? = nil

    /// Anchor pet position captured on drag start. Translations from the
    /// `DragGesture` are applied relative to these, so the pet stays
    /// under the cursor even when the initial position was non-zero.
    private var heldAnchorX: CGFloat = 0
    private var heldAnchorY: CGFloat = 0

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
    /// Each pile has a fixed room-relative x offset, set at spawn so
    /// piles stay where they were dropped instead of following the pet.
    @Published var poopPiles: [PoopPile]
    /// Count-based convenience for logic that doesn't care about position
    /// (care tick caps, UI enable flags, status icon, sickness trigger).
    var poops: Int { poopPiles.count }
    /// Earliest time at which the current pile began accumulating —
    /// used by the sickness rule "poop sitting too long".
    @Published var lastPoopAt: Date?
    /// When the next poop should spawn. Set by `feed()`.
    @Published var poopDueAt: Date?

    // Lifecycle
    @Published var ageActiveSeconds: Double
    @Published var stage: LifecycleStage
    @Published var departedAt: Date?

    // Neglect trackers — how long each critical condition has persisted.
    // Apply at every post-egg stage; a pet can die from sustained neglect
    // whether it's a child, adult, or elder.
    @Published var hungerZeroSeconds: Double
    @Published var happyZeroSeconds: Double
    @Published var sickSeconds: Double

    // Personality
    @Published var personality: PersonalityTrait?
    @Published var careHistory: CareHistory

    // Marriage + breeding (all optional — nil for unmarried pets).
    // Cleared on rebornAsNewGeneration; see `greet()` / `marry()` /
    // `layEgg()` / `hatchBaby()` / `triggerFamilyFarewell()`.
    @Published var partner: PartnerSnapshot? = nil
    @Published var marriedAt: Date? = nil
    @Published var pendingEgg: PendingEgg? = nil
    @Published var pendingBaby: PendingBaby? = nil
    @Published var babyHatchedAtAge: Double? = nil
    @Published var parents: [UUID]? = nil

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
    nonisolated static let maxNameLength: Int = 12

    /// Active seconds of grace a freshly hatched child gets before the
    /// nightly sleep window applies. Prevents "installed at night → pet
    /// never woke up" on the user's first session.
    nonisolated static let newbornGraceSeconds: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_NEWBORN_GRACE_SEC"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 10.0
        #else
        return 3600.0  // 1 real hour of active use
        #endif
    }()

    init(
        id: UUID = UUID(),
        name: String? = nil,
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
        poopPiles: [PoopPile] = [],
        lastPoopAt: Date? = nil,
        poopDueAt: Date? = nil,
        ageActiveSeconds: Double = 0,
        stage: LifecycleStage = .egg,
        departedAt: Date? = nil,
        hungerZeroSeconds: Double = 0,
        happyZeroSeconds: Double = 0,
        sickSeconds: Double = 0,
        personality: PersonalityTrait? = nil,
        careHistory: CareHistory = CareHistory(),
        partner: PartnerSnapshot? = nil,
        marriedAt: Date? = nil,
        pendingEgg: PendingEgg? = nil,
        pendingBaby: PendingBaby? = nil,
        babyHatchedAtAge: Double? = nil,
        parents: [UUID]? = nil
    ) {
        self.id = id
        self.name = name ?? species.defaultName
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
        self.poopPiles = poopPiles
        self.lastPoopAt = lastPoopAt
        self.poopDueAt = poopDueAt
        self.ageActiveSeconds = ageActiveSeconds
        self.stage = stage
        self.departedAt = departedAt
        self.hungerZeroSeconds = hungerZeroSeconds
        self.happyZeroSeconds = happyZeroSeconds
        self.sickSeconds = sickSeconds
        self.personality = personality
        self.careHistory = careHistory
        self.partner = partner
        self.marriedAt = marriedAt
        self.pendingEgg = pendingEgg
        self.pendingBaby = pendingBaby
        self.babyHatchedAtAge = babyHatchedAtAge
        self.parents = parents
    }

    var ageDays: Double {
        ageActiveSeconds / LifecycleClock.activeSecondsPerDay
    }

    // MARK: - Derived state

    var canInteract: Bool {
        !isAsleep && stage != .egg && stage != .departed
    }

    /// Whether the nightly sleep window applies to this pet right now.
    /// Eggs always stay "awake" so hatching keeps progressing; freshly
    /// hatched children get a `newbornGraceSeconds` active-time grace so
    /// a user who installs late at night isn't greeted by an immediately
    /// sleeping pet.
    var observesNightSleep: Bool {
        switch stage {
        case .egg:
            return false
        case .child:
            let hatchAgeSeconds = LifecycleTable().eggHatchDay *
                                  LifecycleClock.activeSecondsPerDay
            return ageActiveSeconds >= hatchAgeSeconds + Self.newbornGraceSeconds
        case .adult, .elder, .departed:
            return true
        }
    }

    /// Temporary post-interaction mood boost (transient; see `.happy` mode).
    var isHappy: Bool {
        guard let until = happyUntil else { return false }
        return until > Date()
    }

    // MARK: - Actions

    /// Apply a user-typed name. Trims whitespace, truncates to
    /// `maxNameLength`, and falls back to the species default if the
    /// input is empty after trimming. Silently no-ops during the egg
    /// stage (name is hidden in UI then).
    func rename(to raw: String) {
        guard stage != .egg else { return }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            name = species.defaultName
            return
        }
        name = String(trimmed.prefix(Self.maxNameLength))
    }

    // MARK: - User interaction (room view)

    /// The user tapped the pet. Pick a personality-aware micro-action
    /// and route it through the existing `.performing` behavior channel
    /// so `PetBehaviorEngine` naturally returns to idle after the reaction
    /// plays out.
    func reactToTap() {
        guard canInteract, !isBeingHeld else { return }

        let reactionMode: PetMode
        let sound: SoundPlayer.Sound?
        switch personality {
        case .cheerful:   reactionMode = .bounce;   sound = .happy
        case .shy:        reactionMode = .hide;     sound = nil
        case .aloof:      reactionMode = .lookaway; sound = nil
        case .gluttonous: reactionMode = .lick;     sound = .happy
        case .lazy:       reactionMode = .yawn;     sound = nil
        case .grumpy:     reactionMode = .huff;     sound = .feedReject
        case nil:         reactionMode = .bounce;   sound = .happy
        }

        activeBehavior = .performing(reactionMode)
        if let s = sound { SoundPlayer.shared.play(s) }
        let deadline = Date().addingTimeInterval(Self.petCursorDuration)
        tapReactionUntil = deadline
        // Clear the marker once the window expires so cursor observers
        // see the state flip back.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.petCursorDuration) { [weak self] in
            guard let self else { return }
            if let current = self.tapReactionUntil, current == deadline {
                self.tapReactionUntil = nil
            }
        }
    }

    /// Begin a drag. The caller (RoomView's DragGesture) supplies the
    /// cumulative translation via `updateHold(translation:)`.
    func startHold() {
        guard canInteract, !isBeingHeld else { return }
        isBeingHeld = true
        heldAnchorX = petX
        heldAnchorY = petY
        activeBehavior = .idle
    }

    /// Update the pet position to follow the drag. Clamped so the pet
    /// can't be flung out of the room frame.
    func updateHold(translation: CGSize) {
        guard isBeingHeld else { return }
        petX = max(Self.heldMinX, min(Self.heldMaxX, heldAnchorX + translation.width))
        petY = max(Self.heldMinY, min(Self.heldMaxY, heldAnchorY + translation.height))
        facingRight = translation.width >= 0
    }

    /// Drop the pet. It walks back to the centre and `petY` springs to 0
    /// (the RoomView attaches a spring animation to `petY`).
    func endHold() {
        guard isBeingHeld else { return }
        isBeingHeld = false
        petY = 0
        activeBehavior = .walking(targetX: 0)
    }

    /// Called when the user opens the notch panel. The pet jogs to the
    /// centre of the room, dances in place for ~1.5s, and shows a
    /// `.happy` expression — "you're back!". Silent no-op during egg /
    /// sleep / departed, or if already busy with another behavior.
    func greet() {
        guard canInteract, !isBeingHeld else { return }
        if case .walking = activeBehavior { return }
        if case .performing = activeBehavior { return }

        // Immediate audio feedback so the click feels responsive, even
        // before the pet has physically walked anywhere.
        SoundPlayer.shared.play(.happy)

        let distance = abs(petX)
        let walkSeconds: Double = distance < 8 ? 0.0 : Double(distance) / 40.0
        let danceSeconds: Double = 1.5

        if walkSeconds > 0 {
            activeBehavior = .walking(targetX: 0)
        }
        // Cover walk + dance + 4s post-greet happy window in one go.
        happyUntil = Date().addingTimeInterval(walkSeconds + danceSeconds + 4.0)

        // Chain walk → dance → idle on the main actor. Each step
        // re-checks `canInteract` / `isBeingHeld` so a sudden sleep /
        // drag / death aborts the sequence cleanly.
        Task { @MainActor [weak self] in
            if walkSeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(walkSeconds * 1_000_000_000))
            }
            guard let self = self, self.canInteract, !self.isBeingHeld else { return }
            self.activeBehavior = .performing(.dance)

            try? await Task.sleep(nanoseconds: UInt64(danceSeconds * 1_000_000_000))
            guard self.canInteract, !self.isBeingHeld else { return }
            // Only clear if we're still dancing — something else could
            // have taken over (feed/play action feedback, drag, etc).
            if case .performing(.dance) = self.activeBehavior {
                self.activeBehavior = .idle
            }
        }
    }

    nonisolated static let petCursorDuration: TimeInterval = 0.6
    nonisolated static let heldMinX: CGFloat = -200
    nonisolated static let heldMaxX: CGFloat = 200

    /// Horizontal offset from the pet's center at which a newly spawned
    /// poop pile is placed. Zero = dropped directly where the pet stood;
    /// a small random jitter on top keeps stacked piles from overlapping.
    nonisolated static let petPoopOffsetX: CGFloat = 0
    nonisolated static let heldMinY: CGFloat = -120
    /// Drag-down clamp. With the floor-anchored room layout (see
    /// `RoomGeometry` in RoomView.swift), `petY == 0` puts the feet on
    /// the floor — any positive drag would push the pet into the
    /// hearts / action bar region below, so we block it outright.
    nonisolated static let heldMaxY: CGFloat = 0

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
        guard !poopPiles.isEmpty else { return }
        poopPiles.removeAll()
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

        let hungerBefore = hunger
        let happyBefore = happy

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

        // Edge-triggered alerts on threshold crossings. Decay is monotonic,
        // so each threshold fires at most once per crossing; a single tick
        // spanning 2→0 may fire both warning and critical, which is fine.
        if hungerBefore > 1, hunger <= 1 { SoundPlayer.shared.play(.feedReject) } // TODO: dedicated hungry_warn.wav
        if hungerBefore > 0, hunger == 0 { SoundPlayer.shared.play(.feedReject) } // TODO: dedicated hungry_alert.wav
        if happyBefore  > 1, happy  <= 1 { SoundPlayer.shared.play(.rest) }       // TODO: dedicated sad_warn.wav
        if happyBefore  > 0, happy  == 0 { SoundPlayer.shared.play(.rest) }       // TODO: dedicated sad_alert.wav
    }

    /// Block 6: new per-tick job for poop spawning + sickness triggers.
    /// Kept separate from `applyDecay` for clarity — decay is a pure
    /// function of elapsed time; this is state-machine logic.
    func runCareTick(now: Date, activeSeconds: Double) {
        guard stage == .child || stage == .adult || stage == .elder else { return }
        guard !isAsleep else { return }

        // Scheduled poop spawn — fix the pile at the pet's current x so
        // it stays where it was dropped, with a small jitter to avoid
        // exact overlap when multiple piles accumulate nearby.
        if let due = poopDueAt, now >= due, poopPiles.count < 3 {
            let jitter = CGFloat.random(in: -14...14)
            let offset = max(Self.heldMinX,
                             min(Self.heldMaxX, petX + Self.petPoopOffsetX + jitter))
            poopPiles.append(PoopPile(xOffset: offset))
            if lastPoopAt == nil { lastPoopAt = now }
            poopDueAt = nil
            triggerActionAnimation(.pooping)
            SoundPlayer.shared.play(.clean) // TODO: dedicated poop_spawn.wav
        }

        // Neglect timer: accumulates while any vital is at 0
        if hunger == 0 || happy == 0 {
            neglectSeconds += activeSeconds
        } else {
            neglectSeconds = 0
        }

        // Neglect death triggers — apply at every post-egg stage. Elder is
        // still the most fragile stage in practice because its 1.5× decay
        // empties hearts faster, but child/adult can also die if ignored.
        hungerZeroSeconds = (hunger == 0) ? hungerZeroSeconds + activeSeconds : 0
        happyZeroSeconds  = (happy == 0)  ? happyZeroSeconds + activeSeconds  : 0
        sickSeconds       = sick ? sickSeconds + activeSeconds : 0

        if hungerZeroSeconds >= Self.hungerDeathSeconds
            || happyZeroSeconds >= Self.happyDeathSeconds
            || sickSeconds >= Self.sickDeathSeconds {
            triggerDeath()
            return
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

    private func triggerDeath() {
        let previous = stage
        stage = .departed
        departedAt = Date()
        handleStageTransition(from: previous, to: .departed)
        // v2 cloud sync — stamp departed_at + final stats on the row.
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await CloudSync.shared.recordDeparture(of: self)
        }
    }

    // MARK: - Marriage + breeding

    /// Commits a partner snapshot received via QR scan. No-op if the
    /// pet is not an eligible adult or already married.
    func marry(with partner: PartnerSnapshot) {
        guard stage == .adult, self.partner == nil else { return }
        self.partner = partner
        self.marriedAt = Date()
        SoundPlayer.shared.play(.happy)
        // v2 cloud sync — record the marriage from our side.
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await CloudSync.shared.pushMarriage(petState: self, partner: partner)
        }
    }

    /// Produces a `PendingEgg` with genes resolved 50/50: one parent
    /// supplies species, the other supplies personality. Called by
    /// `TimeService` when `marriedAt + 1 active-day` is reached.
    func layEgg() {
        guard let partner = partner,
              pendingEgg == nil,
              pendingBaby == nil else { return }
        // Own personality may be nil only in theory (marriage is gated
        // on `.adult` stage), but defend against it just in case.
        let ownPersonality = personality ?? .shy
        let speciesFromMe = Bool.random()
        let babySpecies: Species = speciesFromMe ? species : partner.species
        let babyPersonality: PersonalityTrait = speciesFromMe
            ? partner.personality
            : ownPersonality

        pendingEgg = PendingEgg(
            id: UUID(),
            species: babySpecies,
            personality: babyPersonality,
            laidAt: Date(),
            hatchDueAt: Date().addingTimeInterval(LifecycleClock.activeSecondsPerDay),
            parents: [self.id, partner.id]
        )
        SoundPlayer.shared.play(.happy)
    }

    /// Converts a `pendingEgg` into a `pendingBaby`. Called by
    /// `TimeService` when `eggLaidAt + 1 active-day` is reached.
    func hatchBaby() {
        guard let egg = pendingEgg, pendingBaby == nil else { return }
        pendingBaby = PendingBaby(
            id: egg.id,
            species: egg.species,
            personality: egg.personality,
            name: egg.species.defaultName,
            hatchedAt: Date(),
            parents: egg.parents
        )
        pendingEgg = nil
        babyHatchedAtAge = ageActiveSeconds
        SoundPlayer.shared.play(.hatch)
    }

    /// Natural end-of-life for the parents once the baby has had its
    /// minimum companion time. Shares the `.departed` pipeline so the
    /// same farewell + memorial + reborn flow handles inheritance.
    func triggerFamilyFarewell() {
        guard stage != .departed else { return }
        triggerDeath()
    }

    private func scheduleNextElderSicknessCheck() {
        let window = 2.0 * LifecycleClock.activeSecondsPerDay
        let offset = Double.random(in: (0.3 * window)..<window)
        sicknessCheckDueAt = Date().addingTimeInterval(offset)
    }

    /// Advance the lifecycle clock by `activeSeconds` and recompute stage.
    /// Departed is set only by `triggerDeath()` — the table doesn't
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
    /// If a `pendingBaby` (hatched) or `pendingEgg` (orphan path) exists,
    /// the new pet inherits its species + personality + parents lineage
    /// instead of rolling a random species.
    func rebornAsNewGeneration() {
        awaitingRebornConfirm = false

        // Decide species/personality/parents for the next generation.
        let inheritedSpecies: Species
        let inheritedPersonality: PersonalityTrait?
        let inheritedParents: [UUID]?
        let inheritedName: String?
        let inheritedID: UUID
        if let baby = pendingBaby {
            inheritedSpecies = baby.species
            inheritedPersonality = baby.personality
            inheritedParents = baby.parents
            inheritedName = baby.name
            inheritedID = baby.id
        } else if let egg = pendingEgg {
            // Orphan path — parent died before hatch. Use egg genes.
            inheritedSpecies = egg.species
            inheritedPersonality = egg.personality
            inheritedParents = egg.parents
            inheritedName = nil
            inheritedID = egg.id
        } else {
            // No marriage / baby — random roll as before.
            inheritedSpecies = Species.allCases.randomElement() ?? .chick
            inheritedPersonality = nil
            inheritedParents = nil
            inheritedName = nil
            inheritedID = UUID()
        }

        id = inheritedID
        species = inheritedSpecies
        name = inheritedName ?? inheritedSpecies.defaultName
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
        poopPiles.removeAll()
        lastPoopAt = nil
        poopDueAt = nil
        ageActiveSeconds = 0
        stage = .egg
        departedAt = nil
        hungerZeroSeconds = 0
        happyZeroSeconds = 0
        sickSeconds = 0
        personality = inheritedPersonality
        careHistory.reset()
        hungerDecayAccum = 0
        happyDecayAccum = 0

        // Clear all marriage / pregnancy state — fresh slate.
        partner = nil
        marriedAt = nil
        pendingEgg = nil
        pendingBaby = nil
        babyHatchedAtAge = nil
        parents = inheritedParents
        neglectSeconds = 0
        petX = 0
        petY = 0
        facingRight = true
        activeBehavior = .idle
        isBeingHeld = false
        tapReactionUntil = nil
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

    // MARK: - Fragility constants

    // Elder-only: faster decay and higher random-sickness chance.
    static let elderDecayMultiplier: Double = 1.5
    static let elderSicknessChance: Double = 0.60

    // Neglect death thresholds — shared across child / adult / elder.
    // Env-var keys keep the legacy NOTCHPET_ELDER_* names so existing
    // schemes keep working; the values simply apply at every stage now.
    static var hungerDeathSeconds: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_ELDER_HUNGER_DEATH"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 10.0   // 0.5 debug-days
        #else
        return 0.5 * 86_400.0
        #endif
    }()

    static var happyDeathSeconds: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_ELDER_HAPPY_DEATH"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 20.0   // 1.0 debug-day
        #else
        return 86_400.0
        #endif
    }()

    static var sickDeathSeconds: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_ELDER_SICK_DEATH"],
           let v = Double(raw), v > 0 { return v }
        #if DEBUG
        return 20.0   // 1.0 debug-day
        #else
        return 86_400.0
        #endif
    }()
}
