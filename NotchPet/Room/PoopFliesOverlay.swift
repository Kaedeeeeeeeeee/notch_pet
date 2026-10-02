import SwiftUI

/// A single fly buzzing in a small orbit. Caller positions it (RoomView
/// places one above each poop pile so flies stay with the poop instead
/// of following the pet around).
struct PoopFliesOverlay: View {
    private static let size: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            StatusIconPixelView(kind: .fly, size: Self.size)
                .opacity(0.92)
                .offset(
                    x: CGFloat(sin(t * 4.0)) * 4,
                    y: CGFloat(cos(t * 5.0)) * 3
                )
        }
        .frame(width: Self.size, height: Self.size)
        .allowsHitTesting(false)
    }
}
