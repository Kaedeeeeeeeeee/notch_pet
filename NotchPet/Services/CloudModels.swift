import Foundation

/// DTOs matching the `public.pets` / `public.marriages` schemas. Field
/// naming uses `snake_case` with explicit `CodingKeys` so we preserve
/// Swift's idiomatic `camelCase` on the model side.

struct CloudPet: Codable, Identifiable, Equatable {
    let id: UUID
    let ownerID: UUID
    let name: String
    let species: String
    let personality: String?
    let generation: Int
    let bornAt: Date
    let departedAt: Date?
    let parents: [UUID]?
    let feedCount: Int
    let playCount: Int
    let weight: Int
    let ageActiveSeconds: Double
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID           = "owner_id"
        case name, species, personality, generation
        case bornAt            = "born_at"
        case departedAt        = "departed_at"
        case parents
        case feedCount         = "feed_count"
        case playCount         = "play_count"
        case weight
        case ageActiveSeconds  = "age_active_seconds"
        case updatedAt         = "updated_at"
    }
}

struct CloudMarriage: Codable, Identifiable, Equatable {
    let id: UUID
    let ownerID: UUID
    let ownPetID: UUID
    let partnerPetID: UUID
    let partnerSnapshot: PartnerSnapshot
    let marriedAt: Date
    let endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID          = "owner_id"
        case ownPetID         = "own_pet_id"
        case partnerPetID     = "partner_pet_id"
        case partnerSnapshot  = "partner_snapshot"
        case marriedAt        = "married_at"
        case endedAt          = "ended_at"
    }
}

/// Minimal insertable payload for `pets` upserts — we skip server-owned
/// columns (`created_at`, `updated_at`) so the server fills them in.
struct CloudPetUpsert: Codable, Equatable {
    let id: UUID
    let ownerID: UUID
    let name: String
    let species: String
    let personality: String?
    let generation: Int
    let bornAt: Date
    let departedAt: Date?
    let parents: [UUID]?
    let feedCount: Int
    let playCount: Int
    let weight: Int
    let ageActiveSeconds: Double

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID           = "owner_id"
        case name, species, personality, generation
        case bornAt            = "born_at"
        case departedAt        = "departed_at"
        case parents
        case feedCount         = "feed_count"
        case playCount         = "play_count"
        case weight
        case ageActiveSeconds  = "age_active_seconds"
    }
}

struct CloudMarriageInsert: Codable, Equatable {
    let ownerID: UUID
    let ownPetID: UUID
    let partnerPetID: UUID
    let partnerSnapshot: PartnerSnapshot
    let marriedAt: Date

    enum CodingKeys: String, CodingKey {
        case ownerID          = "owner_id"
        case ownPetID         = "own_pet_id"
        case partnerPetID     = "partner_pet_id"
        case partnerSnapshot  = "partner_snapshot"
        case marriedAt        = "married_at"
    }
}
