import Foundation

/// Serializable snapshot of `PetState`. Kept separate from the ObservableObject
/// class so the observable properties stay cheap and Codable evolution doesn't
/// leak into the UI model.
struct PetStateSnapshot: Codable {
    let schemaVersion: Int
    let id: UUID
    let name: String
    let bornAt: Date
    let generation: Int
    let hunger: Double
    let mood: Double
    let energy: Double
    let isAsleep: Bool
    let lastTickAt: Date
    let ageActiveSeconds: Double
    let stage: LifecycleStage
    let departedAt: Date?
    let personality: PersonalityTrait?
    let careHistory: CareHistory

    @MainActor
    init(from state: PetState) {
        self.schemaVersion = PetStateStore.currentSchema
        self.id = state.id
        self.name = state.name
        self.bornAt = state.bornAt
        self.generation = state.generation
        self.hunger = state.hunger
        self.mood = state.mood
        self.energy = state.energy
        self.isAsleep = state.isAsleep
        self.lastTickAt = state.lastTickAt
        self.ageActiveSeconds = state.ageActiveSeconds
        self.stage = state.stage
        self.departedAt = state.departedAt
        self.personality = state.personality
        self.careHistory = state.careHistory
    }

    @MainActor
    func materialize() -> PetState {
        PetState(
            id: id,
            name: name,
            bornAt: bornAt,
            generation: generation,
            hunger: hunger,
            mood: mood,
            energy: energy,
            isAsleep: isAsleep,
            lastTickAt: lastTickAt,
            ageActiveSeconds: ageActiveSeconds,
            stage: stage,
            departedAt: departedAt,
            personality: personality,
            careHistory: careHistory
        )
    }
}

/// JSON persistence for PetState under ~/Library/Application Support.
@MainActor
final class PetStateStore {
    nonisolated static let currentSchema: Int = 2

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("com.notchpet.NotchPet", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.fileURL = dir.appendingPathComponent("state.json")
    }

    /// Returns persisted state if available, otherwise a freshly hatched pet.
    /// Schema-version mismatches silently fall back to a new pet; MVP accepts
    /// that there's no migration path yet.
    func load() -> PetState {
        guard let data = try? Data(contentsOf: fileURL) else {
            return PetState()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(PetStateSnapshot.self, from: data),
              snapshot.schemaVersion == Self.currentSchema else {
            return PetState()
        }
        return snapshot.materialize()
    }

    func save(_ state: PetState) {
        let snapshot = PetStateSnapshot(from: state)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
