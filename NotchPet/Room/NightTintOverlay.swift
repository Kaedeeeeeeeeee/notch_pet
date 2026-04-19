import SwiftUI

/// Cool-blue atmospheric gradient that fades in during the nightly sleep
/// window (21:00–09:00 by default, personality-shifted via
/// `NightSleepSchedule`). Independent of `petState.isAsleep` — eggs and
/// freshly hatched children stay awake but the *room* still reads as
/// night, which is what the user would expect after dark.
///
/// Sits between `RoomThemeBackground` and the pet/furniture layer so the
/// walls/floor get tinted while the pet sprite stays vibrant.
struct NightTintOverlay: View {
    @ObservedObject var petState: PetState

    private let schedule = NightSleepSchedule()

    var body: some View {
        // Recompute `isNight` once a minute; the precise 21:00 / 09:00
        // transition gets smoothed by the inner `.animation(value:)`.
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            let isNight = schedule.isNightTime(
                at: context.date,
                personality: petState.personality
            )
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.15, blue: 0.35).opacity(0.55),
                    Color(red: 0.15, green: 0.20, blue: 0.40).opacity(0.35),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(isNight ? 1 : 0)
            .animation(.easeInOut(duration: 1.5), value: isNight)
        }
        .allowsHitTesting(false)
    }
}
