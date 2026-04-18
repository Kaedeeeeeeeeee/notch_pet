import SwiftUI

/// Top-level view hosted inside the NotchPanel. Switches between the
/// collapsed notch strip and the expanded room popover based on UI state.
/// Collapse is driven by `NotchPanelController`'s global event monitors, so
/// this view never calls collapse directly.
struct NotchRootView: View {
    @ObservedObject var uiState: NotchPanelState
    @ObservedObject var petState: PetState
    @ObservedObject var inventory: PlayerInventory
    /// How far the collapsed panel extends past the physical notch on each
    /// horizontal side. Used to place the pet / status icon flush against
    /// the left and right extensions rather than inside the cavity.
    let sideExtension: CGFloat
    /// Block 4 shake callback. Wired by `NotchPanelController` when it
    /// builds the hosting view; invoked by action buttons (and by
    /// departed transitions via a separate Notification path).
    let onShake: (NotchPanelController.ShakeIntensity) -> Void

    var body: some View {
        ZStack {
            if uiState.isExpanded {
                RoomView(petState: petState, inventory: inventory, onShake: onShake)
                    .transition(.opacity)
            } else {
                CollapsedNotchView(petState: petState, sideExtension: sideExtension)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: uiState.isExpanded)
        .background(Color.black)
        .clipShape(NotchClipShape(cornerRadius: uiState.isExpanded ? 18 : 10))
        .ignoresSafeArea()
    }
}

/// Rectangle with rounded bottom corners matching the MacBook notch
/// cutout. Top stays flat against the top of the display.
struct NotchClipShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0,
            style: .continuous
        ).path(in: rect)
    }
}

/// Collapsed view. Pet sits inside the left side extension (menu bar area
/// just left of the physical notch), status icon sits inside the right
/// side extension. The middle of the strip overlaps the physical notch
/// cavity and shows pure black, so the whole strip reads as a horizontally
/// stretched notch.
private struct CollapsedNotchView: View {
    @ObservedObject var petState: PetState
    let sideExtension: CGFloat

    private let petSide: CGFloat = 22
    private let iconSide: CGFloat = 16

    var body: some View {
        HStack(spacing: 0) {
            // Left extension: pet sprite, centered inside the extension.
            ZStack {
                PetView(size: petSide, petState: petState, applyMovement: false)
            }
            .frame(width: sideExtension)

            // Middle: physical notch cavity. Pure black.
            Spacer(minLength: 0)

            // Right extension: status indicator.
            ZStack {
                StatusIconView(petState: petState, side: iconSide)
            }
            .frame(width: sideExtension)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Tiny indicator on the right edge of the collapsed strip that surfaces
/// the most urgent pet need. When everything is fine the strip stays black.
private struct StatusIconView: View {
    @ObservedObject var petState: PetState
    let side: CGFloat

    var body: some View {
        ZStack {
            if let kind = currentKind {
                StatusIconPixelView(kind: kind, size: side)
            }
        }
        .frame(width: side, height: side)
    }

    /// Block 6 priority: lifecycle → sleep → sick → poop → hungry →
    /// low happy. Everything below is silent (happy / curious don't
    /// need a notch-strip cue).
    private var currentKind: StatusIconPixelView.Kind? {
        if petState.stage == .egg { return nil }
        if petState.stage == .departed { return .departed }
        if petState.isAsleep { return .sleeping }
        if petState.sick { return .sick }
        if petState.poops > 0 { return .poop }
        // Hunger at 0 beats happy at 0 — empty stomach is the most
        // acute "please do something" beat.
        if petState.hunger == 0 { return .hungry }
        if petState.happy == 0 { return .lowMood }
        // Two hearts or fewer on either vital: subtle pre-warning.
        if petState.hunger <= 1 { return .hungry }
        if petState.happy <= 1 { return .lowMood }
        return nil
    }
}
