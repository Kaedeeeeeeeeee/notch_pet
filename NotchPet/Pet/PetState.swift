import Foundation
import Combine

/// The gameplay state of the pet. Hunger, mood, and energy all live in [0, 1].
/// Decay is applied by `TimeService` only while the computer is active, per
/// the design doc's active-time model. Block 3 adds a lifecycle stage
/// machine, a personality trait fixed at child→adult transition, and a
/// generation counter that ticks over whenever the pet departs and is
/// reborn as a new egg.
@MainActor
final class PetState: ObservableObject {
    // Identity / generation
    @Published var id: UUID
    @Published var name: String
    @Published var bornAt: Date
    @Published var generation: Int

    // Vitals
    @Published var hunger: Double
    @Published var mood: Double
    @Published var energy: Double

    // Runtime flags
    @Published var isAsleep: Bool
    @Published var lastTickAt: Date

    // Lifecycle
    @Published var ageActiveSeconds: Double   // total active seconds since bornAt
    @Published var stage: LifecycleStage
    @Published var departedAt: Date?          // timestamp the pet entered .departed

    // Personality
    @Published var personality: PersonalityTrait?  // nil until child → adult transition
    @Published var careHistory: CareHistory

    init(
        id: UUID = UUID(),
        name: String = "ひよこ",
        bornAt: Date = Date(),
        generation: Int = 1,
        hunger: Double = 0.7,
        mood: Double = 0.7,
        energy: Double = 0.7,
        isAsleep: Bool = false,
        lastTickAt: Date = Date(),
        ageActiveSeconds: Double = 0,
        stage: LifecycleStage = .egg,
        departedAt: Date? = nil,
        personality: PersonalityTrait? = nil,
        careHistory: CareHistory = CareHistory()
    ) {
        self.id = id
        self.name = name
        self.bornAt = bornAt
        self.generation = generation
        self.hunger = hunger
        self.mood = mood
        self.energy = energy
        self.isAsleep = isAsleep
        self.lastTickAt = lastTickAt
        self.ageActiveSeconds = ageActiveSeconds
        self.stage = stage
        self.departedAt = departedAt
        self.personality = personality
        self.careHistory = careHistory
    }

    var ageDays: Double {
        ageActiveSeconds / LifecycleClock.activeSecondsPerDay
    }

    // MARK: - Actions

    var canInteract: Bool {
        !isAsleep && stage != .egg && stage != .departed
    }

    func feed() {
        guard canInteract else { return }
        hunger = min(1.0, hunger + 0.25)
        mood = min(1.0, mood + 0.05)
        careHistory.recordFeed()
    }

    func play() {
        guard canInteract else { return }
        mood = min(1.0, mood + 0.30)
        energy = max(0.0, energy - 0.10)
        careHistory.recordPlay()
    }

    func rest() {
        guard canInteract else { return }
        energy = min(1.0, energy + 0.40)
        mood = max(0.0, mood - 0.05)
        careHistory.recordRest()
    }

    // MARK: - Decay

    /// Apply vital decay for `activeSeconds` of elapsed active computer time.
    /// Rates: energy fast, hunger medium, mood slow.
    func applyDecay(activeSeconds: Double) {
        guard activeSeconds > 0, !isAsleep else { return }
        // Egg / departed phases don't drain vitals — the pet isn't really
        // living yet / anymore.
        guard stage != .egg && stage != .departed else { return }

        let multiplier = Self.decayMultiplier
        let delta = activeSeconds * multiplier

        energy = max(0.0, energy - Self.energyPerSecond * delta)
        hunger = max(0.0, hunger - Self.hungerPerSecond * delta)
        mood   = max(0.0, mood   - Self.moodPerSecond   * delta)
    }

    /// Advance the lifecycle clock by `activeSeconds` and recompute stage.
    /// Called from TimeService every tick while the machine is active.
    func advanceLifecycle(activeSeconds: Double, table: LifecycleTable = LifecycleTable()) {
        guard activeSeconds > 0 else { return }
        ageActiveSeconds += activeSeconds
        let previous = stage
        let next = table.stage(forAgeDays: ageDays)
        if next != previous {
            stage = next
            handleStageTransition(from: previous, to: next)
        }
    }

    private func handleStageTransition(from old: LifecycleStage, to new: LifecycleStage) {
        // Fix personality when the pet matures into adult. The trait is
        // derived from how the user cared for it during .child.
        if old == .child && new == .adult && personality == nil {
            var rng = SystemRandomNumberGenerator()
            personality = careHistory.derivePersonality(rng: &rng)
        }
        if new == .departed && departedAt == nil {
            departedAt = Date()
        }
    }

    /// Reset this state instance to a fresh egg for the next generation.
    /// Called by TimeService after the departed grace window elapses.
    func rebornAsNewGeneration() {
        id = UUID()
        name = "ひよこ"
        bornAt = Date()
        generation += 1
        hunger = 0.7
        mood = 0.7
        energy = 0.7
        isAsleep = false
        lastTickAt = Date()
        ageActiveSeconds = 0
        stage = .egg
        departedAt = nil
        personality = nil
        careHistory.reset()
    }

    // MARK: - Tuning constants

    private static let energyPerSecond = 1.0 / (2.0 * 3600.0)
    private static let hungerPerSecond = 1.0 / (4.0 * 3600.0)
    private static let moodPerSecond   = 1.0 / (8.0 * 3600.0)

    /// Developer acceleration (see DEVELOPMENT_LOG).
    private static var decayMultiplier: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_DECAY_SPEEDUP"],
           let value = Double(raw), value > 0 {
            return value
        }
        #if DEBUG
        return 30.0
        #else
        return 1.0
        #endif
    }()
}
