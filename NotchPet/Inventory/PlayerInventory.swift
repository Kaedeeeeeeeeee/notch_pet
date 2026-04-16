import Foundation
import Combine

/// Slots that a furniture item can occupy in the room. One slot holds
/// at most one item. Block 6 keeps it simple at three static positions.
enum FurnitureSlot: String, Codable, CaseIterable, Hashable {
    case floorLeft
    case floorRight
    case wallBack
}

/// Player-scope inventory state. Lives independently of `PetState` so
/// it survives `rebornAsNewGeneration()` — coins are the player's, not
/// the pet's. Persisted to `inventory.json` alongside `state.json`.
@MainActor
final class PlayerInventory: ObservableObject {
    @Published var coins: Int
    @Published var ownedRoomThemes: Set<String>
    @Published var ownedFurniture: Set<String>
    @Published var activeRoomTheme: String
    @Published var placedFurniture: [FurnitureSlot: String]

    init(
        coins: Int = 0,
        ownedRoomThemes: Set<String> = ["default"],
        ownedFurniture: Set<String> = [],
        activeRoomTheme: String = "default",
        placedFurniture: [FurnitureSlot: String] = [:]
    ) {
        self.coins = coins
        self.ownedRoomThemes = ownedRoomThemes
        self.ownedFurniture = ownedFurniture
        self.activeRoomTheme = activeRoomTheme
        self.placedFurniture = placedFurniture
    }

    // MARK: - Coin operations

    func addCoins(_ amount: Int) {
        guard amount > 0 else { return }
        coins += amount
    }

    func canAfford(_ price: Int) -> Bool {
        coins >= price
    }

    // MARK: - Room themes

    func purchaseRoomTheme(_ id: String, price: Int) -> Bool {
        guard !ownedRoomThemes.contains(id), canAfford(price) else { return false }
        coins -= price
        ownedRoomThemes.insert(id)
        return true
    }

    func equipRoomTheme(_ id: String) {
        guard ownedRoomThemes.contains(id) else { return }
        activeRoomTheme = id
    }

    // MARK: - Furniture

    func purchaseFurniture(_ id: String, price: Int) -> Bool {
        guard !ownedFurniture.contains(id), canAfford(price) else { return false }
        coins -= price
        ownedFurniture.insert(id)
        return true
    }

    func placeFurniture(_ id: String, in slot: FurnitureSlot) {
        guard ownedFurniture.contains(id) else { return }
        placedFurniture[slot] = id
    }

    func removeFurniture(from slot: FurnitureSlot) {
        placedFurniture.removeValue(forKey: slot)
    }
}
