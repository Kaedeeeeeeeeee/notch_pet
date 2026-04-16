import Foundation

/// Coarse life-cycle stages. Elder is open-ended: a well-cared-for pet
/// lives indefinitely. Departed is triggered only by sustained neglect
/// during the elder stage (hunger/happy at zero too long, or untreated
/// sickness). A new generation respawns automatically after departure.
enum LifecycleStage: String, Codable {
    case egg        // Day 0.0 – 0.5
    case child      // Day 0.5 – 5.0  (growing, personality still malleable)
    case adult      // Day 5.0 – 8.0  (mature, personality fixed)
    case elder      // Day 8.0+       (fragile, needs careful care)
    case departed   // neglect death   (farewell, brief window before respawn)
}

/// Maps an age in active days to the current lifecycle stage.
struct LifecycleTable {
    var eggHatchDay: Double = 0.5
    var childToAdultDay: Double = 5.0
    var adultToElderDay: Double = 8.0

    func stage(forAgeDays age: Double) -> LifecycleStage {
        switch age {
        case ..<eggHatchDay:        return .egg
        case ..<childToAdultDay:    return .child
        case ..<adultToElderDay:    return .adult
        default:                    return .elder
        }
    }
}

/// How many seconds of active computer time count as one pet-day. Release
/// builds follow the design doc's "one real day of active use = one day",
/// debug builds compress the full 10-day cycle into ~3 minutes so you can
/// see every stage transition during smoke tests.
enum LifecycleClock {
    static var activeSecondsPerDay: Double = {
        if let raw = ProcessInfo.processInfo.environment["NOTCHPET_DAY_SECONDS"],
           let value = Double(raw), value > 0 {
            return value
        }
        #if DEBUG
        return 20.0  // 20s = 1 day → full 10-day life in ~3 minutes
        #else
        return 86_400.0
        #endif
    }()

    /// Grace window the pet lingers in `.departed` before a new egg drops.
    static var departGraceSeconds: Double { activeSecondsPerDay * 0.5 }
}
