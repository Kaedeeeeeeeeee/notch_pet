import AppKit
import SwiftUI

/// NSHostingView specialised for a non-activating panel. Two jobs:
/// 1. Accept the first mouse click even when the panel is non-key
///    (default `NSView.acceptsFirstMouse` returns false, which swallows
///    the expand gesture on a `.nonactivatingPanel`).
/// 2. Forward clicks that land in the collapsed strip directly to an
///    AppKit-level handler, bypassing SwiftUI's gesture recognizer (which
///    doesn't receive events reliably on non-activating panels).
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    /// Invoked on every left mouse-down. The controller uses this to toggle
    /// between collapsed and expanded panel layouts.
    var onMouseDown: (() -> Void)?
    /// Fires true on mouseEntered, false on mouseExited. SwiftUI's `.onHover`
    /// is unreliable inside a non-activating panel, so hover detection lives
    /// here as an NSTrackingArea on the AppKit host view.
    var onHoverChange: ((Bool) -> Void)?

    required init(rootView: Content) { super.init(rootView: rootView) }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @MainActor required dynamic init(rootView: Content, tracksContentSize: Bool) {
        super.init(rootView: rootView)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        // Forward to SwiftUI so buttons inside the expanded RoomView (collapse
        // chevron, future action buttons) still receive the click. The
        // collapsed strip intentionally has no SwiftUI tap gesture, so this
        // forward is a no-op while collapsed.
        super.mouseDown(with: event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }
}
