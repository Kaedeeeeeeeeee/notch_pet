import AppKit

/// Borderless panel that sits over the MacBook notch. Based on the window
/// construction used by boring.notch (TheBoredTeam/boring.notch): a non-
/// activating utility/HUD panel pinned to the top of the main screen. MVP
/// avoids the private CGSSpace / SkyLight level hack — we rely on public
/// APIs: `.statusBar` level + broad collection behavior.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        worksWhenModal = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .none
        // Non-activating panels don't deliver mouseMoved events to child
        // views by default — which means NSTrackingArea cursorUpdate and
        // SwiftUI .onHover never fire. Opt in so the pet cursor rect
        // (RoomView → CursorRect) can trigger.
        acceptsMouseMovedEvents = true
    }

    /// The panel is non-activating, so by default it can't become key —
    /// keystrokes never reach SwiftUI, which is why the TextField that
    /// edits the pet's name looks focused but swallows every key. The
    /// controller flips this on for the duration of an inline text edit
    /// and flips it back off when the edit commits.
    var acceptsKeyboardFocus: Bool = false {
        didSet {
            guard oldValue != acceptsKeyboardFocus else { return }
            if !acceptsKeyboardFocus, isKeyWindow {
                // Hand key status back so ESC / click-outside go through the
                // usual global event monitors again.
                resignKey()
            }
        }
    }

    override var canBecomeKey: Bool { acceptsKeyboardFocus }
    override var canBecomeMain: Bool { false }
}
