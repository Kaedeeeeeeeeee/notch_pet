import Foundation

/// Serializable snapshot of `PetState`. Block 6 is schema v3: discrete
/// integer hearts (replacing 0–1 floats), added sickness + poop fields,
/// dropped `energy` entirely.
struct PetStateSnapshot: Codable {
    let schemaVersion: Int
    let id: UUID
    let name: String
    let bornAt: Date
    let generation: Int
    let species: Species?
    let hunger: Int
    let happy: Int
    let weight: Int
    let isAsleep: Bool
    let lastTickAt: Date
    let sick: Bool
    let medicineDosesRemaining: Int
    let sicknessCheckDueAt: Date?
    let poops: Int
    let lastPoopAt: Date?
    let poopDueAt: Date?
    let ageActiveSeconds: Double
    let stage: LifecycleStage
    let departedAt: Date?
    let elderHungerZeroSeconds: Double?
    let elderHappyZeroSeconds: Double?
    let elderSickSeconds: Double?
    let personality: PersonalityTrait?
    let careHistory: CareHistory

    @MainActor
    init(from state: PetState) {
        self.schemaVersion = PetStateStore.currentSchema
        self.id = state.id
        self.name = state.name
        self.bornAt = state.bornAt
        self.generation = state.generation
        self.species = state.species
        self.hunger = state.hunger
        self.happy = state.happy
        self.weight = state.weight
        self.isAsleep = state.isAsleep
        self.lastTickAt = state.lastTickAt
        self.sick = state.sick
        self.medicineDosesRemaining = state.medicineDosesRemaining
        self.sicknessCheckDueAt = state.sicknessCheckDueAt
        self.poops = state.poops
        self.lastPoopAt = state.lastPoopAt
        self.poopDueAt = state.poopDueAt
        self.ageActiveSeconds = state.ageActiveSeconds
        self.stage = state.stage
        self.departedAt = state.departedAt
        self.elderHungerZeroSeconds = state.elderHungerZeroSeconds
        self.elderHappyZeroSeconds = state.elderHappyZeroSeconds
        self.elderSickSeconds = state.elderSickSeconds
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
            species: species ?? .chick,
            hunger: hunger,
            happy: happy,
            weight: weight,
            isAsleep: isAsleep,
            lastTickAt: lastTickAt,
            sick: sick,
            medicineDosesRemaining: medicineDosesRemaining,
            sicknessCheckDueAt: sicknessCheckDueAt,
            poops: poops,
            lastPoopAt: lastPoopAt,
            poopDueAt: poopDueAt,
            ageActiveSeconds: ageActiveSeconds,
            stage: stage,
            departedAt: departedAt,
            elderHungerZeroSeconds: elderHungerZeroSeconds ?? 0,
            elderHappyZeroSeconds: elderHappyZeroSeconds ?? 0,
            elderSickSeconds: elderSickSeconds ?? 0,
            personality: personality,
            careHistory: careHistory
        )
    }
}

/// v2 shape (Blocks 2–5): retained so we can migrate old state.json
/// files forward without losing the user's pet.
private struct PetStateSnapshotV2: Codable {
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
}

/// JSON persistence for PetState under ~/Library/Application Support.
@MainActor
final class PetStateStore {
    nonisolated static let currentSchema: Int = 4

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
    /// Block 6 adds a v2 → v3 migration path so existing installs carry
    /// their pet forward.
    func load() -> PetState {
        guard let data = try? Data(contentsOf: fileURL) else {
            return PetState()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // v4 path (also accepts v3 — species defaults to .chick when missing)
        if let snapshot = try? decoder.decode(PetStateSnapshot.self, from: data),
           snapshot.schemaVersion >= 3 {
            let state = snapshot.materialize()
            // awaitingRebornConfirm is transient — infer from persisted state
            // so the reborn overlay reappears after an app restart.
            if state.stage == .departed, let dep = state.departedAt,
               Date().timeIntervalSince(dep) >= LifecycleClock.departGraceSeconds {
                state.awaitingRebornConfirm = true
            }
            if snapshot.schemaVersion < Self.currentSchema { save(state) }
            return state
        }

        // v2 → v3 migration
        if let v2 = try? decoder.decode(PetStateSnapshotV2.self, from: data),
           v2.schemaVersion == 2 {
            let migrated = PetState(
                id: v2.id,
                name: v2.name,
                bornAt: v2.bornAt,
                generation: v2.generation,
                hunger: Self.floatToHearts(v2.hunger),
                happy: Self.floatToHearts(v2.mood),
                weight: PetState.initialWeight,
                isAsleep: v2.isAsleep,
                lastTickAt: v2.lastTickAt,
                sick: false,
                medicineDosesRemaining: 0,
                sicknessCheckDueAt: nil,
                poops: 0,
                lastPoopAt: nil,
                poopDueAt: nil,
                ageActiveSeconds: v2.ageActiveSeconds,
                stage: v2.stage,
                departedAt: v2.departedAt,
                personality: v2.personality,
                careHistory: v2.careHistory
            )
            save(migrated)
            return migrated
        }

        // Unknown schema / parse error — start fresh
        return PetState()
    }

    /// Map a v2 0.0–1.0 float vital onto a discrete 0–4 heart count.
    private static func floatToHearts(_ value: Double) -> Int {
        let hearts = Int((value * Double(PetState.maxHearts)).rounded())
        return max(0, min(PetState.maxHearts, hearts))
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
