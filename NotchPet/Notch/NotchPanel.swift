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
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
