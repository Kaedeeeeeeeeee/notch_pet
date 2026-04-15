import Foundation

/// Nightly window during which the pet freezes all vital decay and the UI
/// switches to a sleep layout. Hours are in the user's local timezone using
/// Calendar.current, matching the design doc's "no TZ special casing" rule.
struct NightSleepSchedule {
    var sleepHour: Int = 21  // 21:00 local
    var wakeHour: Int = 9    // 09:00 local

    /// True if `now` falls inside the configured [sleepHour, wakeHour) window.
    /// Handles the common cross-midnight case (sleep 21:00, wake 09:00).
    func isNightTime(at now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: now)
        if sleepHour == wakeHour { return false }
        if sleepHour < wakeHour {
            return hour >= sleepHour && hour < wakeHour
        } else {
            // crosses midnight
            return hour >= sleepHour || hour < wakeHour
        }
    }
}
