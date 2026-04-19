import Foundation

/// Frozen snapshot of a partner's pet, received via QR exchange and
/// stored locally. We intentionally only keep the 5 visible traits —
/// species + personality + name — so the partner can be rendered with
/// the local sprite library. No live state sync; the partner lives on
/// forever in the user's room until their own pet departs.
struct PartnerSnapshot: Codable, Equatable {
    let id: UUID
    let species: Species
    let personality: PersonalityTrait
    let name: String
    let marriedAt: Date
}

/// A freshly laid egg waiting to hatch. Genes are pre-resolved at the
/// moment of laying (50/50 species/personality split between parents)
/// so the baby's identity is deterministic once the egg exists — even
/// if both parents die before hatching.
struct PendingEgg: Codable, Equatable {
    let id: UUID
    let species: Species
    let personality: PersonalityTrait
    let laidAt: Date
    let hatchDueAt: Date
    let parents: [UUID]
}

/// A hatched baby coexisting with its parents until the family farewell
/// triggers the next-generation transition. Sprite rendering uses the
/// `.child` stage; once adopted as the active pet it promotes naturally.
struct PendingBaby: Codable, Equatable {
    let id: UUID
    let species: Species
    let personality: PersonalityTrait
    let name: String
    let hatchedAt: Date
    let parents: [UUID]
}
