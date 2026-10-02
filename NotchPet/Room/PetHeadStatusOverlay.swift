import SwiftUI

/// Floating pixel-art status icon shown above the pet's head when
/// something needs attention: sickness, empty hunger, or empty mood.
/// Only one icon shows at a time (sick > hungry > lowMood). Suppressed
/// during sleep / egg / departed because those states have their own
/// dedicated overlays. Poop has its own per-pile fly overlay
/// (`PoopFliesOverlay`) — it is no longer surfaced here.
///
/// Position is owned by the caller (RoomView places it relative to the
/// pet's current `petX` so it follows walk/drag motion).
struct PetHeadStatusOverlay: View {
    @ObservedObject var petState: PetState

    private static let size: CGFloat = 18

    var body: some View {
        ZStack {
            if let kind = relevantKind {
                let critical = petState.isCriticallyLow
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let offset = motion(for: kind, t: t, critical: critical)
                    // 0.4s red flash cycle while critical so the icon
                    // feels like a blinking warning light, not just a
                    // static red sprite.
                    let flashPhase = (sin(t * (2 * .pi / 0.4)) + 1) / 2
                    let redTint = critical
                        ? Color(red: 1.0, green: 0.25, blue: 0.25)
                            .opacity(0.55 + 0.45 * flashPhase)
                        : Color.clear
                    StatusIconPixelView(kind: kind, size: Self.size)
                        .opacity(0.92)
                        .overlay(
                            StatusIconPixelView(kind: kind, size: Self.size)
                                .colorMultiply(redTint)
                                .opacity(critical ? 1 : 0)
                                .blendMode(.plusLighter)
                        )
                        .scaleEffect(critical ? 1.0 + 0.15 * flashPhase : 1.0,
                                     anchor: .center)
                        .offset(x: offset.x, y: offset.y)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        // Slightly larger frame so the scaled-up critical pulse isn't
        // clipped by the original 18×18 hit region.
        .frame(width: Self.size * 1.3, height: Self.size * 1.3)
        .animation(.easeInOut(duration: 0.3), value: relevantKind)
        .allowsHitTesting(false)
    }

    /// Priority follows `PetState.attentionReason` so the expanded room
    /// and collapsed notch surface the same care beat.
    private var relevantKind: StatusIconPixelView.Kind? {
        switch petState.attentionReason {
        case .needsPoop: return .toilet
        case .sick: return .sick
        case .poop: return .poop
        case .hungry: return .hungry
        case .lowMood: return .lowMood
        case .discipline: return .discipline
        case nil: return nil
        }
    }

    /// Vertical bob. Critical pets bob ~3× faster with a larger
    /// amplitude so the head icon literally shakes for attention.
    private func motion(
        for kind: StatusIconPixelView.Kind,
        t: Double,
        critical: Bool
    ) -> CGPoint {
        if critical {
            let bobY = CGFloat(sin(t * (2 * .pi / 0.45))) * 3.5
            return CGPoint(x: 0, y: bobY)
        } else if kind == .toilet || kind == .discipline {
            let shakeX = CGFloat(sin(t * (2 * .pi / 0.25))) * 2.5
            return CGPoint(x: shakeX, y: -1)
        } else {
            let bobY = CGFloat(sin(t * (2 * .pi / 1.5))) * 2
            return CGPoint(x: 0, y: bobY)
        }
    }
}
