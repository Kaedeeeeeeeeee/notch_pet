import Foundation

/// Serializable snapshot of `PetState`. Kept separate from the ObservableObject
/// class so the observable properties stay cheap and Codable evolution doesn't
/// leak into the UI model.
struct PetStateSnapshot: Codable {
    let id: UUID
    let name: String
    let bornAt: Date
    let hunger: Double
    let mood: Double
    let energy: Double
    let isAsleep: Bool
    let lastTickAt: Date
    /// Schema version — bump when fields change in an incompatible way.
    let schemaVersion: Int

    @MainActor
    init(from state: PetState) {
        self.id = state.id
        self.name = state.name
        self.bornAt = state.bornAt
        self.hunger = state.hunger
        self.mood = state.mood
        self.energy = state.energy
        self.isAsleep = state.isAsleep
        self.lastTickAt = state.lastTickAt
        self.schemaVersion = PetStateStore.currentSchema
    }

    @MainActor
    func materialize() -> PetState {
        PetState(
            id: id,
            name: name,
            bornAt: bornAt,
            hunger: hunger,
            mood: mood,
            energy: energy,
            isAsleep: isAsleep,
            lastTickAt: lastTickAt
        )
    }
}

/// JSON persistence for PetState under ~/Library/Application Support.
@MainActor
final class PetStateStore {
    nonisolated static let currentSchema: Int = 1

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
    func load() -> PetState {
        guard let data = try? Data(contentsOf: fileURL) else {
            return PetState()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(PetStateSnapshot.self, from: data) else {
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
