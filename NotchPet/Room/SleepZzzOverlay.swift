import SwiftUI

/// Floating "Zzz" above the pet's head while `petState.isAsleep`. Replaces
/// the old full-screen scrim — subtle pixel-style rise/grow/fade loop so
/// the sleep state is communicated without hiding the room art.
///
/// Position is owned by the caller: place this view inside the same
/// GeometryReader that positions the pet, anchored above the sprite.
struct SleepZzzOverlay: View {
    /// Loop duration in seconds. Matches the sprite's 2s breathing cycle
    /// so body + Zzz feel unified.
    private static let period: Double = 2.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.period) / Self.period
            // Scale grows 0.55 → 1.35, opacity fades 0 → 0.95 → 0, drifts up.
            let scale  = 0.55 + CGFloat(t) * 0.80
            let rise   = CGFloat(t) * 18
            // Bell-shaped alpha so the Zzz fades in at start and out at end.
            let alpha  = Double(sin(.pi * t)) * 0.95

            Text("Zzz")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(alpha))
                .shadow(color: Color.black.opacity(0.4 * alpha), radius: 1, y: 1)
                .scaleEffect(scale, anchor: .bottomLeading)
                .offset(y: -rise)
        }
        .allowsHitTesting(false)
    }
}
