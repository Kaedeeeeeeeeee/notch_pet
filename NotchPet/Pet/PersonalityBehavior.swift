import Foundation

/// Block 5: per-personality gameplay tuning. Each trait gets a small
/// bundle of computed properties that modify the pet's behavior. The
/// values are intentionally conservative — we want each personality to
/// feel distinct, not punitive.
///
/// See `notch-pet-product-design.md` §4.2 for the intended behaviors.

/// Pet species — the primary visual differentiator. Each species has
/// its own base body art in the spritesheet. Personality adds subtle
/// expression/behavior tweaks on top, not body-shape changes.
enum Species: String, Codable, CaseIterable {
    case chick
}

extension PersonalityTrait {
    /// Tag suffix used in the spritesheet for this personality's
    /// expression variant. Matches the tag segment emitted by `gen_pet.lua`.
    var tagName: String { rawValue }

    /// Multiplier on `hunger` decay rate. Gluttonous pets get hungry
    /// noticeably faster — the only decay change in Block 5.
    var hungerDecayMultiplier: Double {
        switch self {
        case .gluttonous: return 1.40
        default:          return 1.00
        }
    }

    /// Probability that a `feed()` call actually lands. Aloof pets turn
    /// their head away about 1 in 5 times and the food goes nowhere.
    var feedAcceptProbability: Double {
        switch self {
        case .aloof: return 0.80
        default:     return 1.00
        }
    }

    /// Hours added to the nightly wake time. Lazy pets sleep in until
    /// 10:00 instead of the default 09:00.
    var wakeHourOffset: Int {
        switch self {
        case .lazy: return 1
        default:    return 0
        }
    }

    /// Grumpy pets flip into `.angry` mode when a vital hits zero. The
    /// actual comparison is now a boolean "any vital is empty" — kept as
    /// an optional so non-grumpy personalities short-circuit before
    /// even checking the vitals.
    var angerTriggerThreshold: Int? {
        switch self {
        case .grumpy: return 0
        default:      return nil
        }
    }
}
