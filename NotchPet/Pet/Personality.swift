import Foundation

/// Primary personality trait. The design doc lists six dimensions with
/// distinct behavior effects; Block 3 keeps a single dominant trait per
/// generation, derived from how the user cared for the pet during the
/// `.child` stage. Block 3 wires the visual hint and one or two gameplay
/// nudges; broader animation/voice differentiation lands in Block 4.
enum PersonalityTrait: String, Codable, CaseIterable {
    case cheerful   // 活泼
    case shy        // 害羞
    case aloof      // 高冷
    case gluttonous // 贪吃
    case lazy       // 懒惰
    case grumpy     // 暴躁

    var displayName: String {
        switch self {
        case .cheerful:   return "活泼"
        case .shy:        return "害羞"
        case .aloof:      return "高冷"
        case .gluttonous: return "贪吃"
        case .lazy:       return "懒惰"
        case .grumpy:     return "暴躁"
        }
    }

    /// Tint multiplier applied to the chick body color to make the trait
    /// legible at a glance on the collapsed strip.
    var bodyTint: (r: Double, g: Double, b: Double) {
        switch self {
        case .cheerful:   return (1.10, 1.05, 1.00)   // warm brighter
        case .shy:        return (1.00, 1.00, 1.10)   // faint blue
        case .aloof:      return (0.85, 0.95, 1.10)   // cooler
        case .gluttonous: return (1.10, 0.95, 0.85)   // ruddier
        case .lazy:       return (0.90, 0.90, 0.90)   // muted
        case .grumpy:     return (1.15, 0.85, 0.85)   // reddish
        }
    }
}

/// Counters that record how the user cared for the pet while it was a child.
/// The dominant action becomes the personality trait when the pet matures.
struct CareHistory: Codable {
    var feedCount: Int = 0
    var playCount: Int = 0
    var restCount: Int = 0

    mutating func recordFeed() { feedCount += 1 }
    mutating func recordPlay() { playCount += 1 }
    mutating func recordRest() { restCount += 1 }

    mutating func reset() {
        feedCount = 0
        playCount = 0
        restCount = 0
    }

    /// Derive a personality trait from the care pattern. The mapping is
    /// deliberately simple so that a player's intent translates cleanly:
    ///
    /// - many feeds → gluttonous
    /// - many plays → cheerful
    /// - many rests → lazy
    /// - balanced / neglected → shy (as a soft default)
    ///
    /// A small chance of rolling one of the rarer traits (aloof / grumpy)
    /// adds surprise in line with the design doc's "variation" section.
    func derivePersonality(rng: inout SystemRandomNumberGenerator) -> PersonalityTrait {
        let total = feedCount + playCount + restCount
        if total < 3 {
            return .shy
        }
        // 12% chance of a surprise trait regardless of care pattern.
        if Double.random(in: 0..<1, using: &rng) < 0.12 {
            return Bool.random(using: &rng) ? .aloof : .grumpy
        }
        let maxCount = max(feedCount, max(playCount, restCount))
        if maxCount == feedCount { return .gluttonous }
        if maxCount == playCount { return .cheerful }
        return .lazy
    }
}
