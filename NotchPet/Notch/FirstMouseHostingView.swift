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
}
