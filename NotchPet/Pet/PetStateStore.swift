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
    /// v5: individual piles with fixed positions. Decoded as nil from
    /// older saves; see `init(from:)` fallback below for migration.
    let poopPiles: [PoopPile]?
    /// v3/v4 count-only field. Kept optional so v5 saves (which rely on
    /// `poopPiles` instead) can omit it without breaking the decoder.
    let poops: Int?
    let lastPoopAt: Date?
    let poopDueAt: Date?
    let ageActiveSeconds: Double
    let stage: LifecycleStage
    let departedAt: Date?
    // Persisted under their historical JSON keys (elder*) so saves written
    // before neglect-death applied at all stages still decode cleanly.
    let hungerZeroSeconds: Double?
    let happyZeroSeconds: Double?
    let sickSeconds: Double?
    let personality: PersonalityTrait?
    let careHistory: CareHistory
    // v4: marriage + breeding. All optional; nil = pet is single /
    // childless. Old v3 state.json will decode these as nil cleanly
    // because Swift's synthesized Codable treats missing keys for
    // Optional properties as nil.
    let partner: PartnerSnapshot?
    let marriedAt: Date?
    let pendingEgg: PendingEgg?
    let pendingBaby: PendingBaby?
    let babyHatchedAtAge: Double?
    let parents: [UUID]?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, bornAt, generation, species
        case hunger, happy, weight, isAsleep, lastTickAt
        case sick, medicineDosesRemaining, sicknessCheckDueAt
        case poops, poopPiles, lastPoopAt, poopDueAt
        case ageActiveSeconds, stage, departedAt
        case hungerZeroSeconds = "elderHungerZeroSeconds"
        case happyZeroSeconds = "elderHappyZeroSeconds"
        case sickSeconds = "elderSickSeconds"
        case personality, careHistory
        case partner, marriedAt, pendingEgg, pendingBaby
        case babyHatchedAtAge, parents
    }

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
        self.poopPiles = state.poopPiles
        self.poops = nil  // superseded by poopPiles in v5+
        self.lastPoopAt = state.lastPoopAt
        self.poopDueAt = state.poopDueAt
        self.ageActiveSeconds = state.ageActiveSeconds
        self.stage = state.stage
        self.departedAt = state.departedAt
        self.hungerZeroSeconds = state.hungerZeroSeconds
        self.happyZeroSeconds = state.happyZeroSeconds
        self.sickSeconds = state.sickSeconds
        self.personality = state.personality
        self.careHistory = state.careHistory
        self.partner = state.partner
        self.marriedAt = state.marriedAt
        self.pendingEgg = state.pendingEgg
        self.pendingBaby = state.pendingBaby
        self.babyHatchedAtAge = state.babyHatchedAtAge
        self.parents = state.parents
    }

    /// Resolve poop piles for materialization. Prefer v5 positions when
    /// present; otherwise synthesize placeholder piles at x=0 from the
    /// old integer count so an upgrading user doesn't lose their "pet
    /// needs cleaning" state.
    private func materializedPoopPiles() -> [PoopPile] {
        if let piles = poopPiles { return piles }
        let count = max(0, min(3, poops ?? 0))
        return (0..<count).map { _ in PoopPile(xOffset: 0) }
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
            poopPiles: materializedPoopPiles(),
            lastPoopAt: lastPoopAt,
            poopDueAt: poopDueAt,
            ageActiveSeconds: ageActiveSeconds,
            stage: stage,
            departedAt: departedAt,
            hungerZeroSeconds: hungerZeroSeconds ?? 0,
            happyZeroSeconds: happyZeroSeconds ?? 0,
            sickSeconds: sickSeconds ?? 0,
            personality: personality,
            careHistory: careHistory,
            partner: partner,
            marriedAt: marriedAt,
            pendingEgg: pendingEgg,
            pendingBaby: pendingBaby,
            babyHatchedAtAge: babyHatchedAtAge,
            parents: parents
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
    nonisolated static let currentSchema: Int = 5

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
            return PetState(species: Self.randomSpecies())
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
                poopPiles: [],
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
        return PetState(species: Self.randomSpecies())
    }

    /// Map a v2 0.0–1.0 float vital onto a discrete 0–4 heart count.
    private static func floatToHearts(_ value: Double) -> Int {
        let hearts = Int((value * Double(PetState.maxHearts)).rounded())
        return max(0, min(PetState.maxHearts, hearts))
    }

    private static func randomSpecies() -> Species {
        Species.allCases.randomElement() ?? .chick
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
