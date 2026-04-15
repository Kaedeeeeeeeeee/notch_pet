import Foundation

/// Block 1 stub. Real state machine (hunger, mood, energy, lifecycle stage,
/// personality vector, genealogy) lands in Block 2 / Block 3. For now this
/// is just the identity envelope — enough that references in other files
/// compile without implying the full model exists yet.
struct PetState {
    let id: UUID
    var name: String

    static let placeholder = PetState(id: UUID(), name: "ひよこ")
}
