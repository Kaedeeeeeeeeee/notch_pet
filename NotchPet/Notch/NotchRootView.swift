import SwiftUI

/// Top-level view hosted inside the NotchPanel. Switches between the
/// collapsed notch strip and the expanded room popover based on UI state.
/// Collapse is driven by `NotchPanelController`'s global event monitors, so
/// this view never calls collapse directly.
struct NotchRootView: View {
    @ObservedObject var uiState: NotchPanelState
    @ObservedObject var petState: PetState
    /// Height in points of the physical MacBook notch cavity. Content above
    /// this line sits inside the real notch cutout; below it sits on the
    /// menu bar and is where the rounded bottom corners live.
    let cavityHeight: CGFloat

    var body: some View {
        ZStack {
            if uiState.isExpanded {
                RoomView(petState: petState)
                    .transition(.opacity)
            } else {
                CollapsedNotchView(petState: petState, cavityHeight: cavityHeight)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: uiState.isExpanded)
        .background(Color.black)
        .clipShape(NotchClipShape(cornerRadius: uiState.isExpanded ? 18 : 12))
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

/// Collapsed view sized to fit over the physical notch. Pet lives on the
/// left, state indicator on the right, with the middle left as pure black
/// so it melts visually into the notch cavity.
private struct CollapsedNotchView: View {
    @ObservedObject var petState: PetState
    let cavityHeight: CGFloat

    private let petSide: CGFloat = 22
    private let iconSide: CGFloat = 16

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            PetView(size: petSide, petState: petState)
                .padding(.leading, 6)
                .padding(.top, max(0, (cavityHeight - petSide) / 2))
            Spacer(minLength: 0)
            StatusIconView(petState: petState, side: iconSide)
                .padding(.trailing, 8)
                .padding(.top, max(0, (cavityHeight - iconSide) / 2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
