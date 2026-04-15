import SwiftUI

/// Top-level view hosted inside the NotchPanel. Switches between the
/// collapsed notch strip and the expanded room popover based on state.
struct NotchRootView: View {
    @ObservedObject var state: NotchPanelState
    /// Invoked when the user triggers a collapse inside SwiftUI (e.g. the
    /// chevron button in RoomView). Collapsed-strip taps are handled at the
    /// AppKit layer via `FirstMouseHostingView.onMouseDown`, not here.
    let onCollapseRequested: () -> Void

    var body: some View {
        ZStack {
            if state.isExpanded {
                RoomView(onCollapse: onCollapseRequested)
                    .transition(.opacity)
            } else {
                CollapsedNotchView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.isExpanded)
        .background(Color.black)
        .ignoresSafeArea()
    }
}

/// Collapsed view sized to fit over the physical notch. Pure black background
/// fuses it visually with the notch bezel; the pet sprite lives in the middle.
/// This view has no tap gesture — AppKit mouseDown on the hosting view toggles
/// the expand.
private struct CollapsedNotchView: View {
    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            PetView(size: 24)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
