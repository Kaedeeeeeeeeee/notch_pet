import SwiftUI

/// Floating pixel-art status icon shown above the pet's head when
/// something needs attention: sickness, empty hunger, empty mood, or
/// poop on the floor. Only one icon shows at a time (sick highest
/// priority, fly lowest). Suppressed during sleep / egg / departed
/// because those states have their own dedicated overlays.
///
/// Position is owned by the caller (RoomView places it relative to the
/// pet's current `petX` so it follows walk/drag motion).
struct PetHeadStatusOverlay: View {
    @ObservedObject var petState: PetState

    private static let size: CGFloat = 18

    var body: some View {
        ZStack {
            if let kind = relevantKind {
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let offset = motion(for: kind, t: t)
                    StatusIconPixelView(kind: kind, size: Self.size)
                        .opacity(0.92)
                        .offset(x: offset.x, y: offset.y)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .frame(width: Self.size, height: Self.size)
        .animation(.easeInOut(duration: 0.3), value: relevantKind)
        .allowsHitTesting(false)
    }

    /// Priority: sick > hungry > lowMood > fly. Silent during sleep /
    /// egg / departed — those stages have their own overlays.
    private var relevantKind: StatusIconPixelView.Kind? {
        if petState.isAsleep { return nil }
        if petState.stage == .egg || petState.stage == .departed { return nil }
        if petState.sick { return .sick }
        if petState.hunger == 0 { return .hungry }
        if petState.happy == 0 { return .lowMood }
        if petState.poops > 0 { return .fly }
        return nil
    }

    /// Fly buzzes around in a small orbit; everyone else does a slow
    /// vertical bob.
    private func motion(for kind: StatusIconPixelView.Kind, t: Double) -> CGPoint {
        if kind == .fly {
            return CGPoint(
                x: CGFloat(sin(t * 4.0)) * 4,
                y: CGFloat(cos(t * 5.0)) * 3
            )
        }
        let bobY = CGFloat(sin(t * (2 * .pi / 1.5))) * 2
        return CGPoint(x: 0, y: bobY)
    }
}
