import Foundation

/// One item in the furniture shop. IDs double as Aseprite tag names so
/// `FurnitureSpriteLibrary` can do a direct lookup.
struct FurnitureDefinition: Identifiable, Hashable {
    let id: String              // Aseprite tag name
    let displayName: String     // Chinese label
    let price: Int              // coins
    let allowedSlots: [FurnitureSlot]
}

enum FurnitureCatalog {
    static let all: [FurnitureDefinition] = [
        FurnitureDefinition(
            id: "ball",
            displayName: "小球",
            price: 25,
            allowedSlots: [.floorLeft, .floorRight]
        ),
        FurnitureDefinition(
            id: "table",
            displayName: "小木桌",
            price: 30,
            allowedSlots: [.floorLeft, .floorRight]
        ),
        FurnitureDefinition(
            id: "cushion",
            displayName: "软垫",
            price: 35,
            allowedSlots: [.floorLeft, .floorRight]
        ),
        FurnitureDefinition(
            id: "plant",
            displayName: "盆栽",
            price: 40,
            allowedSlots: [.floorLeft, .floorRight]
        ),
        FurnitureDefinition(
            id: "lantern",
            displayName: "灯笼",
            price: 50,
            allowedSlots: [.wallBack]
        ),
        FurnitureDefinition(
            id: "poster",
            displayName: "海报",
            price: 60,
            allowedSlots: [.wallBack]
        ),
    ]

    static func find(_ id: String) -> FurnitureDefinition? {
        all.first(where: { $0.id == id })
    }
}
