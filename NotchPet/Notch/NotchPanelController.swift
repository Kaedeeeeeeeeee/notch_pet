import AppKit
import SwiftUI
import Combine

@MainActor
final class NotchPanelController: NSObject {
    private let panel: NotchPanel
    private let uiState = NotchPanelState()
    private let petState: PetState
    private var observers: [NSObjectProtocol] = []
    private var globalEscMonitor: Any?
    private var globalClickMonitor: Any?

    /// The built-in MacBook screen that physically owns the notch. Resolved
    /// once at init; re-resolved on screen change so external display
    /// reconfigurations keep the pet on the MacBook.
    private var hostScreen: NSScreen

    /// Collapsed frame shown over the notch. We extend the physical notch
    /// down by `notchExtensionBelow` points so there's room to curve the
    /// bottom corners below the real cutout — otherwise the rounding has
    /// nowhere to live. The extra height lives on the menu bar directly
    /// below the notch, which is empty in practice.
    private var collapsedSize: CGSize {
        let notch = hostScreen.notchSize ?? CGSize(width: 200, height: 32)
        return CGSize(width: notch.width, height: notch.height + Self.notchExtensionBelow)
    }

    /// Expanded frame shown below the notch (room popover).
    private let expandedSize = CGSize(width: 360, height: 460)

    /// How many points the panel extends below the physical notch cut-out.
    /// The bottom `notchExtensionBelow` points is where the rounded corners
    /// live; anything higher sits inside the real notch cavity.
    static let notchExtensionBelow: CGFloat = 16
    /// Height of the physical notch, used by SwiftUI subviews that want to
    /// position content inside the cavity vs the extension below it.
    var notchCavityHeight: CGFloat {
        hostScreen.notchSize?.height ?? 32
    }

    init(screen: NSScreen, petState: PetState) {
        self.hostScreen = screen
        self.petState = petState
        let initialSize = screen.notchSize ?? CGSize(width: 200, height: 32)
        let contentRect = NSRect(origin: .zero, size: initialSize)
        self.panel = NotchPanel(contentRect: contentRect)
        super.init()
        installRootView()
        installObservers()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        if let m = globalEscMonitor { NSEvent.removeMonitor(m) }
        if let m = globalClickMonitor { NSEvent.removeMonitor(m) }
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    // MARK: - Root view

    private func installRootView() {
        let root = NotchRootView(
            uiState: uiState,
            petState: petState,
            cavityHeight: notchCavityHeight
        )
        let host = FirstMouseHostingView(rootView: root)
        host.autoresizingMask = [.width, .height]
        host.onMouseDown = { [weak self] in
            guard let self else { return }
            // Only the collapsed strip expands on bare clicks. When already
            // expanded, SwiftUI buttons inside the room handle the click via
            // super.mouseDown → NSHostingView dispatch.
            if !self.uiState.isExpanded {
                self.expand()
            }
        }
        panel.contentView = host
    }

    // MARK: - Expand / collapse

    func expand() {
        guard !uiState.isExpanded else { return }
        uiState.isExpanded = true
        animateFrame(to: expandedFrame())
        installDismissMonitors()
    }

    func collapse() {
        guard uiState.isExpanded else { return }
        removeDismissMonitors()
        uiState.isExpanded = false
        animateFrame(to: collapsedFrame())
    }

    private func animateFrame(to frame: NSRect) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    // MARK: - Global dismiss monitors

    /// Installs event monitors that close the expanded panel when the user
    /// presses ESC or clicks anywhere outside the panel. `addGlobalMonitor`
    /// only fires for events delivered to *other* apps, so clicks inside our
    /// own non-activating panel don't trigger it — SwiftUI buttons still work.
    private func installDismissMonitors() {
        if globalEscMonitor == nil {
            globalEscMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return }
                // virtualKey 53 = ESC
                if event.keyCode == 53 {
                    Task { @MainActor in self.collapse() }
                }
            }
        }
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self else { return }
                // `.nonactivatingPanel` clicks reach both our mouseDown
                // override AND the global monitor. Hit-test against the
                // panel's current frame so clicks inside the room don't
                // trigger a collapse.
                let location = NSEvent.mouseLocation  // screen coords
                Task { @MainActor in
                    if !self.panel.frame.contains(location) {
                        self.collapse()
                    }
                }
                _ = event
            }
        }
    }

    private func removeDismissMonitors() {
        if let m = globalEscMonitor {
            NSEvent.removeMonitor(m)
            globalEscMonitor = nil
        }
        if let m = globalClickMonitor {
            NSEvent.removeMonitor(m)
            globalClickMonitor = nil
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
        let target = uiState.isExpanded ? expandedFrame() : collapsedFrame()
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

/// Shared observable state for the panel's expand/collapse UI. Distinct from
/// `PetState`, which owns the gameplay model.
@MainActor
final class NotchPanelState: ObservableObject {
    @Published var isExpanded: Bool = false
}
