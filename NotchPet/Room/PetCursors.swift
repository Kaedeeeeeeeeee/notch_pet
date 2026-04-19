import AppKit
import os

private let cursorLog = Logger(subsystem: "com.notchpet.NotchPet", category: "cursor")

/// Loads the three pixel-art hand cursors bundled under `Cursors/` and
/// hands out the right `NSCursor` based on current pet interaction state.
/// Only used by `RoomView` — the collapsed notch strip keeps the system
/// arrow.
@MainActor
final class PetCursors {
    static let shared = PetCursors()

    let openHand: NSCursor
    let closedHand: NSCursor
    let pettingHand: NSCursor

    private init() {
        // Hotspots are picked to line up with each sprite's "active" pixel —
        // the fingertip for the open/pet variants, the centre of the fist
        // for the closed grab. Tuned against the 16x16 designs in
        // `tools/sprites/gen_cursors.lua`.
        self.openHand    = Self.load("hand_open",   hotSpot: NSPoint(x: 4, y: 1))
        self.closedHand  = Self.load("hand_closed", hotSpot: NSPoint(x: 7, y: 4))
        self.pettingHand = Self.load("hand_pet",    hotSpot: NSPoint(x: 7, y: 11))
    }

    /// Select the cursor that matches the pet's current interaction state.
    func cursor(for state: PetState) -> NSCursor {
        if state.isBeingHeld { return closedHand }
        if let until = state.tapReactionUntil, until > Date() { return pettingHand }
        return openHand
    }

    private static func load(_ name: String, hotSpot: NSPoint) -> NSCursor {
        let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Cursors")
            ?? Bundle.main.url(forResource: name, withExtension: "png")
        guard let url, let image = NSImage(contentsOf: url) else {
            cursorLog.error("PetCursors: failed to load \(name).png from bundle")
            return NSCursor.pointingHand
        }
        cursorLog.debug("PetCursors: loaded \(name) from \(url.lastPathComponent)")
        // Pixel-art cursors: keep nearest-neighbor on Retina upscale.
        image.size = NSSize(width: 16, height: 16)
        return NSCursor(image: image, hotSpot: hotSpot)
    }
}
