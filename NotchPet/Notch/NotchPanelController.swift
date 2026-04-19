import AppKit
import SwiftUI
import Combine

@MainActor
final class NotchPanelController: NSObject {
    /// Relative magnitude of a shake effect. `light` is the default
    /// feedback for `feed/play/rest`; `heavy` is reserved for the death
    /// → reborn transition.
    enum ShakeIntensity {
        case light
        case heavy
    }

    private let panel: NotchPanel
    private let uiState = NotchPanelState()
    private let petState: PetState
    let inventory: PlayerInventory
    private var observers: [NSObjectProtocol] = []
    private var globalEscMonitor: Any?
    private var globalClickMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var shakeTask: Task<Void, Never>?
    /// 30 Hz timer that polls the mouse cursor against the pet hit rect
    /// while the panel is expanded. Polling is the reliable path — built-in
    /// tracking / hover machinery doesn't fire consistently in a
    /// non-activating panel, even with `acceptsMouseMovedEvents = true`.
    private var cursorPollTimer: Timer?
    private var isShowingPetCursor: Bool = false

    /// The built-in MacBook screen that physically owns the notch. Resolved
    /// once at init; re-resolved on screen change so external display
    /// reconfigurations keep the pet on the MacBook.
    private var hostScreen: NSScreen

    /// Collapsed frame. The panel is exactly as tall as the physical notch
    /// cavity, but extends sideways by `sideExtension` on each side so the
    /// pet sprite and status icon have real estate that sits on the menu
    /// bar to the left / right of the physical cutout. The black background
    /// flows seamlessly into the notch because the cavity is already black.
    private var collapsedSize: CGSize {
        let notch = hostScreen.notchSize ?? CGSize(width: 200, height: 32)
        return CGSize(
            width: notch.width + 2 * Self.sideExtension,
            height: notch.height
        )
    }

    /// Expanded frame shown below the notch (room popover). Block 6
    /// polish: wider + slightly shorter so the room reads as a horizontal
    /// house with room for furniture on both sides of the pet.
    private let expandedSize = CGSize(width: 540, height: 400)

    /// How many points the collapsed strip extends beyond the physical notch
    /// on each horizontal side. The pet (22pt) and status icon (16pt) live
    /// inside these extensions.
    static let sideExtension: CGFloat = 34

    /// Extra width added to the collapsed panel while the mouse is hovering.
    /// Split evenly on both sides so the pet / icon drift outward slightly.
    private static let hoverWidthGrowth: CGFloat = 10
    /// Extra height added on hover. The panel is top-anchored to the screen,
    /// so the growth drops downward and the bottom corners puff out from the
    /// physical notch cavity.
    private static let hoverHeightGrowth: CGFloat = 3

    init(screen: NSScreen, petState: PetState, inventory: PlayerInventory) {
        self.hostScreen = screen
        self.petState = petState
        self.inventory = inventory
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
            inventory: inventory,
            sideExtension: Self.sideExtension,
            onShake: { [weak self] intensity in
                self?.shake(intensity)
            },
            onKeyboardFocusRequest: { [weak self] active in
                self?.setKeyboardFocusActive(active)
            }
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
        host.onHoverChange = { [weak self] hovered in
            guard let self else { return }
            self.uiState.isHovered = hovered
            // Block 5: let the pet react to being looked at.
            // Curious mode only triggers in the collapsed strip — when
            // expanded, the panel already has focus and extra "curious"
            // feedback would be noisy.
            self.petState.isHovered = hovered && !self.uiState.isExpanded
        }
        panel.contentView = host
    }

    // MARK: - Expand / collapse

    func expand() {
        guard !uiState.isExpanded else { return }
        uiState.isExpanded = true
        // Clear the curious hover state on expand — the room UI is its
        // own focus, and a lingering `.curious` would override sleeping /
        // hungry / etc while the user is looking at the bars.
        petState.isHovered = false
        animateFrame(to: expandedFrame())
        installDismissMonitors()
        startCursorPolling()
    }

    func collapse() {
        guard uiState.isExpanded else { return }
        removeDismissMonitors()
        uiState.isExpanded = false
        animateFrame(to: collapsedFrame(hovered: uiState.isHovered))
        stopCursorPolling()
    }

    private func animateFrame(to frame: NSRect, duration: TimeInterval = 0.28) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    // MARK: - Custom cursor polling
    //
    // A non-activating panel doesn't reliably deliver mouseMoved events
    // to child views — tracking areas and SwiftUI `.onHover` both go dark.
    // We bypass the event layer entirely and poll the global mouse
    // position against a computed pet rect. Simple, cheap, always works.

    private func startCursorPolling() {
        stopCursorPolling()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollCursor() }
        }
        RunLoop.main.add(t, forMode: .common)
        cursorPollTimer = t
    }

    private func stopCursorPolling() {
        cursorPollTimer?.invalidate()
        cursorPollTimer = nil
        if isShowingPetCursor {
            NSCursor.arrow.set()
            isShowingPetCursor = false
        }
    }

    /// Screen-space center of the pet sprite, given current panel frame
    /// and pet offsets. RoomView layout is a fixed VStack (header / spacer
    /// / pet / spacer / hearts / actions), so the pet's vertical centre
    /// from the top of the expanded 540×400 panel is stable — tuned by
    /// eye to land on the sprite.
    private static let petYFromPanelTop: CGFloat = 190
    /// Half-size of the square hit area around the pet (`RoomView.petHitSize`).
    private static let petHitRadius: CGFloat = 42

    private func pollCursor() {
        guard uiState.isExpanded, panel.isVisible else { return }

        let frame = panel.frame
        let mouse = NSEvent.mouseLocation

        // Pet centre in screen coords (NSEvent uses bottom-left origin,
        // panel.frame.maxY is the top edge of the panel in screen coords).
        let petScreenX = frame.origin.x + frame.width / 2 + petState.petX
        let petScreenY = frame.maxY - Self.petYFromPanelTop - petState.petY

        let dx = abs(mouse.x - petScreenX)
        let dy = abs(mouse.y - petScreenY)
        let inside = dx < Self.petHitRadius && dy < Self.petHitRadius

        if inside && petState.canInteract {
            PetCursors.shared.cursor(for: petState).set()
            isShowingPetCursor = true
        } else if isShowingPetCursor {
            NSCursor.arrow.set()
            isShowingPetCursor = false
        }
    }

    // MARK: - Keyboard focus

    /// Allow / disallow the panel to accept keystrokes. Called by SwiftUI
    /// views that host an inline text editor (e.g. the pet-name field in
    /// the room). Without this the non-activating panel never becomes
    /// key and `TextField` input is silently dropped.
    func setKeyboardFocusActive(_ active: Bool) {
        panel.acceptsKeyboardFocus = active
        if active {
            panel.makeKey()
        }
    }

    // MARK: - Shake feedback

    /// Nudges the panel horizontally for a short, decaying keyframe
    /// sequence. Used for feed/play/rest feedback (`.light`) and for the
    /// farewell transition on `.departed` (`.heavy`). On completion the
    /// panel is snapped back to its authoritative frame via `reposition()`
    /// so a mid-shake screen-parameter change can't leave it off-center.
    func shake(_ intensity: ShakeIntensity) {
        guard AppSettings.shared.shakeEnabled else { return }
        // A new heavy shake supersedes any in-progress light shake.
        if shakeTask != nil, intensity == .light { return }
        shakeTask?.cancel()

        let amplitude: CGFloat
        let stepDuration: Double
        switch intensity {
        case .light:
            amplitude = 1.5
            stepDuration = 0.035
        case .heavy:
            amplitude = 4
            stepDuration = 0.040
        }
        let base = panel.frame
        // Decaying keyframe scales, signs alternating.
        var scales: [CGFloat] = [-1.0, 1.0, -0.7, 0.7, -0.4, 0.4, 0.0]
        if intensity == .heavy {
            scales = [-1.0, 1.0, -0.85, 0.85, -0.65, 0.65, -0.4, 0.4, 0.0]
        }

        shakeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for scale in scales {
                if Task.isCancelled { break }
                let offset = amplitude * scale
                let shifted = NSRect(
                    x: base.origin.x + offset,
                    y: base.origin.y,
                    width: base.size.width,
                    height: base.size.height
                )
                self.panel.setFrame(shifted, display: true)
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
            }
            self.shakeTask = nil
            self.reposition()
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

    private func collapsedFrame(hovered: Bool = false) -> NSRect {
        var size = collapsedSize
        if hovered {
            size.width += Self.hoverWidthGrowth
            size.height += Self.hoverHeightGrowth
        }
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
        let target = uiState.isExpanded
            ? expandedFrame()
            : collapsedFrame(hovered: uiState.isHovered)
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

        // Block 4: shake hard when the pet departs. PetState posts this
        // notification from `handleStageTransition` so it stays ignorant
        // of the view layer.
        observers.append(nc.addObserver(
            forName: .notchPetDidDepart,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.shake(.heavy) }
        })

        // Grow the collapsed strip slightly while the mouse is over it.
        // Only active while collapsed — during an expanded room session the
        // hover state is tracked but ignored so it doesn't fight the expand
        // animation.
        uiState.$isHovered
            .removeDuplicates()
            .sink { [weak self] hovered in
                guard let self else { return }
                guard !self.uiState.isExpanded else { return }
                self.animateFrame(
                    to: self.collapsedFrame(hovered: hovered),
                    duration: 0.15
                )
            }
            .store(in: &cancellables)
    }
}

/// Shared observable state for the panel's expand/collapse UI. Distinct from
/// `PetState`, which owns the gameplay model.
@MainActor
final class NotchPanelState: ObservableObject {
    @Published var isExpanded: Bool = false
    /// True while the mouse is inside the collapsed notch strip. Drives a
    /// subtle "puff" — the panel frame grows a few points so the notch looks
    /// slightly larger under the cursor. Ignored while expanded.
    @Published var isHovered: Bool = false
}
