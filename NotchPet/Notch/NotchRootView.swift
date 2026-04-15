import SwiftUI

/// Top-level view hosted inside the NotchPanel. Switches between the
/// collapsed notch strip and the expanded room popover based on UI state.
/// Collapse is driven by `NotchPanelController`'s global event monitors, so
/// this view never calls collapse directly.
struct NotchRootView: View {
    @ObservedObject var uiState: NotchPanelState
    @ObservedObject var petState: PetState

    var body: some View {
        ZStack {
            if uiState.isExpanded {
                RoomView(petState: petState)
                    .transition(.opacity)
            } else {
                CollapsedNotchView(petState: petState)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: uiState.isExpanded)
        .background(Color.black)
        .ignoresSafeArea()
    }
}

/// Collapsed view sized to fit over the physical notch. Pure black background
/// fuses it visually with the notch bezel; the pet sprite lives in the middle.
/// No tap gesture — AppKit mouseDown on the hosting view drives expand.
private struct CollapsedNotchView: View {
    @ObservedObject var petState: PetState

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            PetView(size: 24, petState: petState)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
