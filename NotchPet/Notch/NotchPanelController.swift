import AppKit
import SwiftUI
import Combine

@MainActor
final class NotchPanelController: NSObject {
    private let panel: NotchPanel
    private let state = NotchPanelState()
    private var observers: [NSObjectProtocol] = []
    /// The built-in MacBook screen that physically owns the notch. Resolved
    /// once at init; re-resolved on screen change so external display
    /// reconfigurations keep the pet on the MacBook.
    private var hostScreen: NSScreen

    /// Collapsed frame shown in the notch itself.
    private var collapsedSize: CGSize {
        hostScreen.notchSize ?? CGSize(width: 200, height: 32)
    }

    /// Expanded frame shown below the notch (room popover).
    private let expandedSize = CGSize(width: 360, height: 420)

    init(screen: NSScreen) {
        self.hostScreen = screen
        let initialSize = screen.notchSize ?? CGSize(width: 200, height: 32)
        let contentRect = NSRect(origin: .zero, size: initialSize)
        self.panel = NotchPanel(contentRect: contentRect)
        super.init()
        installRootView()
        installObservers()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    // MARK: - Root view

    private func installRootView() {
        let root = NotchRootView(state: state) { [weak self] in
            self?.collapse()
        }
        let host = FirstMouseHostingView(rootView: root)
        host.autoresizingMask = [.width, .height]
        host.onMouseDown = { [weak self] in
            guard let self else { return }
            // Only the collapsed strip expands on bare clicks. When already
            // expanded, SwiftUI buttons inside the room handle the click.
            if !self.state.isExpanded {
                self.expand()
            }
        }
        panel.contentView = host
    }

    // MARK: - Expand / collapse

    func toggle() {
        if state.isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    func expand() {
        guard !state.isExpanded else { return }
        state.isExpanded = true
        animateFrame(to: expandedFrame())
    }

    func collapse() {
        guard state.isExpanded else { return }
        state.isExpanded = false
        animateFrame(to: collapsedFrame())
    }

    private func animateFrame(to frame: NSRect) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    // MARK: - Positioning

    private func collapsedFrame() -> NSRect {
        let size = collapsedSize
        let frame = hostScreen.frame
        let x = frame.midX - size.width / 2
        let y = frame.maxY - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func expandedFrame() -> NSRect {
        let size = expandedSize
        let frame = hostScreen.frame
        let x = frame.midX - size.width / 2
        let y = frame.maxY - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    func reposition() {
        let target = state.isExpanded ? expandedFrame() : collapsedFrame()
        panel.setFrame(target, display: true)
    }

    // MARK: - Observers

    private func installObservers() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let refreshed = NSScreen.builtInNotchedScreen {
                    self.hostScreen = refreshed
                }
                self.reposition()
            }
        })

        observers.append(nc.addObserver(
            forName: .notchPanelRequestCollapse,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.collapse() }
        })

        let wsnc = NSWorkspace.shared.notificationCenter
        observers.append(wsnc.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.panel.orderFrontRegardless() }
        })
    }
}

/// Shared observable state passed into the SwiftUI root view so the controller
/// can drive layout transitions without recreating the hosting view.
@MainActor
final class NotchPanelState: ObservableObject {
    @Published var isExpanded: Bool = false
}
