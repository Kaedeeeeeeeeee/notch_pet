import Foundation

/// Nightly window during which the pet freezes all vital decay and the UI
/// switches to a sleep layout. Hours are in the user's local timezone using
/// Calendar.current, matching the design doc's "no TZ special casing" rule.
///
/// Block 5: `wakeHour` can be shifted per personality — lazy pets sleep
/// in one extra hour, so the wake time is pushed from 09:00 to 10:00.
struct NightSleepSchedule {
    var sleepHour: Int = 21  // 21:00 local
    var baseWakeHour: Int = 9    // 09:00 local (default, pre-personality)

    /// True if `now` falls inside the night window for a pet with the
    /// given personality. Nil personality uses the base wake hour (egg /
    /// child before personality is fixed).
    func isNightTime(
        at now: Date = Date(),
        personality: PersonalityTrait? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        let hour = calendar.component(.hour, from: now)
        let wakeHour = baseWakeHour + (personality?.wakeHourOffset ?? 0)
        if sleepHour == wakeHour { return false }
        if sleepHour < wakeHour {
            return hour >= sleepHour && hour < wakeHour
        } else {
            // crosses midnight
            return hour >= sleepHour || hour < wakeHour
        }
    }
}
