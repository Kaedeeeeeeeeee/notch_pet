import SwiftUI
import AppKit
import os

private let cursorLog = Logger(subsystem: "com.notchpet.NotchPet", category: "cursor")

/// Installs a `cursorUpdate`-based tracking area over a SwiftUI view so
/// a custom `NSCursor` shows reliably even inside a `.nonactivatingPanel`,
/// where both SwiftUI's hover-driven `NSCursor.push/pop` and the classic
/// `addCursorRect` mechanism are flaky.
struct CursorRect: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> HostView {
        let v = HostView()
        v.cursor = cursor
        return v
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.cursor = cursor
    }

    final class HostView: NSView {
        var cursor: NSCursor = .arrow {
            didSet {
                // If the mouse is currently over us, apply the new cursor
                // immediately — tracking-area events only fire on motion.
                if isHovering { cursor.set() }
            }
        }
        private var tracking: NSTrackingArea?
        private var isHovering: Bool = false

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let t = tracking { removeTrackingArea(t) }
            let opts: NSTrackingArea.Options = [
                .cursorUpdate,
                .mouseEnteredAndExited,
                .activeAlways,
                .inVisibleRect,
            ]
            let t = NSTrackingArea(rect: bounds, options: opts, owner: self)
            addTrackingArea(t)
            tracking = t
            cursorLog.debug("CursorRect: tracking area installed, bounds=\(String(describing: self.bounds))")
        }

        override func mouseEntered(with event: NSEvent) {
            isHovering = true
            cursor.set()
            cursorLog.debug("CursorRect: mouseEntered → set cursor")
        }

        override func mouseExited(with event: NSEvent) {
            isHovering = false
            cursorLog.debug("CursorRect: mouseExited")
        }

        override func cursorUpdate(with event: NSEvent) {
            cursor.set()
        }

        // Stay transparent to mouse events so SwiftUI gestures on the
        // foreground still work.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
