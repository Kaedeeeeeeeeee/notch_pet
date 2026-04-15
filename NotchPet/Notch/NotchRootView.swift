import SwiftUI

/// Top-level view hosted inside the NotchPanel. Switches between the
/// collapsed notch strip and the expanded room popover based on UI state.
/// Collapse is driven by `NotchPanelController`'s global event monitors, so
/// this view never calls collapse directly.
struct NotchRootView: View {
    @ObservedObject var uiState: NotchPanelState
    @ObservedObject var petState: PetState
    /// How far the collapsed panel extends past the physical notch on each
    /// horizontal side. Used to place the pet / status icon flush against
    /// the left and right extensions rather than inside the cavity.
    let sideExtension: CGFloat

    var body: some View {
        ZStack {
            if uiState.isExpanded {
                RoomView(petState: petState)
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
                PetView(size: petSide, petState: petState)
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
            if let emoji = currentIcon {
                Text(emoji)
                    .font(.system(size: side))
            }
        }
        .frame(width: side, height: side)
    }

    /// Priority: lifecycle → sleep → lowest vital.
    private var currentIcon: String? {
        if petState.stage == .egg { return nil }
        if petState.stage == .departed { return "👋" }
        if petState.isAsleep { return "💤" }

        // Most urgent vital first. Threshold 0.30 so the cue fires a little
        // before the sprite's hungry animation does (0.25 in PetView).
        let threshold = 0.30
        let vitals: [(Double, String)] = [
            (petState.hunger, "🍚"),
            (petState.energy, "⚡️"),
            (petState.mood, "💔"),
        ]
        guard let worst = vitals.min(by: { $0.0 < $1.0 }), worst.0 < threshold else {
            return nil
        }
        return worst.1
    }
}
