import Foundation
import Combine

/// The gameplay state of the pet. Hunger, mood, and energy all live in [0, 1].
/// Decay is applied by `TimeService` only while the computer is active, per
/// the design doc's active-time model. Block 2 keeps personality and
/// lifecycle out of scope — those arrive in Block 3.
@MainActor
final class PetState: ObservableObject {
    // Identity
    let id: UUID
    @Published var name: String
    let bornAt: Date

    // Vitals (0 = empty, 1 = full)
    @Published var hunger: Double
    @Published var mood: Double
    @Published var energy: Double

    // Runtime flags
    @Published var isAsleep: Bool
    @Published var lastTickAt: Date

    init(
        id: UUID = UUID(),
        name: String = "ひよこ",
        bornAt: Date = Date(),
        hunger: Double = 0.7,
        mood: Double = 0.7,
        energy: Double = 0.7,
        isAsleep: Bool = false,
        lastTickAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.bornAt = bornAt
        self.hunger = hunger
        self.mood = mood
        self.energy = energy
        self.isAsleep = isAsleep
        self.lastTickAt = lastTickAt
    }

    // MARK: - Actions

    func feed() {
        guard !isAsleep else { return }
        hunger = min(1.0, hunger + 0.25)
        mood = min(1.0, mood + 0.05)
    }

    func play() {
        guard !isAsleep else { return }
        mood = min(1.0, mood + 0.30)
        energy = max(0.0, energy - 0.10)
    }

    func rest() {
        guard !isAsleep else { return }
        energy = min(1.0, energy + 0.40)
        mood = max(0.0, mood - 0.05)
    }

    // MARK: - Decay

    /// Apply vital decay for `activeSeconds` of elapsed active computer time.
    /// Rates: energy fast, hunger medium, mood slow. Values picked so that a
    /// full bar drains in a couple of hours (energy) to most of a workday
    /// (mood), matching the design doc's "fast / medium / slow" guidance.
    func applyDecay(activeSeconds: Double) {
        guard activeSeconds > 0, !isAsleep else { return }
        // Accelerate in debug so state changes are visible during testing.
        let multiplier = Self.decayMultiplier
        let delta = activeSeconds * multiplier

        energy = max(0.0, energy - Self.energyPerSecond * delta)
        hunger = max(0.0, hunger - Self.hungerPerSecond * delta)
        mood   = max(0.0, mood   - Self.moodPerSecond   * delta)
    }

    // MARK: - Tuning constants

    /// Full bar (1.0) drains in `drainSeconds` of active time at multiplier 1.
    private static let energyPerSecond = 1.0 / (2.0 * 3600.0)   // 2 active hours
    private static let hungerPerSecond = 1.0 / (4.0 * 3600.0)   // 4 active hours
    private static let moodPerSecond   = 1.0 / (8.0 * 3600.0)   // 8 active hours

    /// Developer acceleration. Set NOTCHPET_DECAY_SPEEDUP=N in the launch env
    /// (or a Debug build with the default multiplier below) to make decay
    /// visible during smoke tests. Release builds ship with 1.0.
    private static var decayMultiplier: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_DECAY_SPEEDUP"],
           let value = Double(raw), value > 0 {
            return value
        }
        #if DEBUG
        return 30.0  // ~2min to drain energy; useful for visual QA
        #else
        return 1.0
        #endif
    }()
}
