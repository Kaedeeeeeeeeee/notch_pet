import Foundation

/// Codable snapshot of `PlayerInventory`. Independent schema from
/// `PetStateSnapshot` — Block 6 is v1. `placedFurniture` is stored as
/// a flat `[String: String]` (slot rawValue → item id) so the JSON
/// stays human-readable — Swift's default Dictionary encoder only
/// preserves keyed-container semantics for `String` / `Int` keys.
private struct InventorySnapshot: Codable {
    let schemaVersion: Int
    let coins: Int
    let ownedRoomThemes: Set<String>
    let ownedFurniture: Set<String>
    let activeRoomTheme: String
    let placedFurniture: [String: String]

    @MainActor
    init(from inventory: PlayerInventory) {
        self.schemaVersion = InventoryStore.currentSchema
        self.coins = inventory.coins
        self.ownedRoomThemes = inventory.ownedRoomThemes
        self.ownedFurniture = inventory.ownedFurniture
        self.activeRoomTheme = inventory.activeRoomTheme
        self.placedFurniture = Dictionary(
            uniqueKeysWithValues: inventory.placedFurniture.map { ($0.key.rawValue, $0.value) }
        )
    }
}

@MainActor
final class InventoryStore {
    nonisolated static let currentSchema: Int = 1

    private let fileURL: URL
    /// Serial background queue for JSON encode + disk write. Same
    /// rationale as `PetStateStore.ioQueue` — keep `fsync` off the
    /// main actor so care-action coin earns never block the UI.
    private let ioQueue = DispatchQueue(
        label: "com.notchpet.inventorystore.io",
        qos: .utility
    )

    init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("com.notchpet.NotchPet", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.fileURL = dir.appendingPathComponent("inventory.json")
    }

    func load() -> PlayerInventory {
        guard let data = try? Data(contentsOf: fileURL) else {
            return PlayerInventory()
        }
        let decoder = JSONDecoder()
        guard let snap = try? decoder.decode(InventorySnapshot.self, from: data),
              snap.schemaVersion == Self.currentSchema else {
            return PlayerInventory()
        }
        var placed: [FurnitureSlot: String] = [:]
        for (slotRaw, itemId) in snap.placedFurniture {
            if let slot = FurnitureSlot(rawValue: slotRaw) {
                placed[slot] = itemId
            }
        }
        return PlayerInventory(
            coins: snap.coins,
            ownedRoomThemes: snap.ownedRoomThemes,
            ownedFurniture: snap.ownedFurniture,
            activeRoomTheme: snap.activeRoomTheme,
            placedFurniture: placed
        )
    }

    /// Fire-and-forget save. Snapshot is captured synchronously on the
    /// main actor, then the encode + atomic write run on `ioQueue`.
    func save(_ inventory: PlayerInventory) {
        let snap = InventorySnapshot(from: inventory)
        let url = fileURL
        ioQueue.async {
            Self.writeSnapshot(snap, to: url)
        }
    }

    /// Synchronous flush for `applicationWillTerminate` — blocks the
    /// caller until every queued write has landed on disk.
    func flushSync(_ inventory: PlayerInventory) {
        let snap = InventorySnapshot(from: inventory)
        let url = fileURL
        ioQueue.sync {
            Self.writeSnapshot(snap, to: url)
        }
    }

    private nonisolated static func writeSnapshot(
        _ snap: InventorySnapshot,
        to url: URL
    ) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snap) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
