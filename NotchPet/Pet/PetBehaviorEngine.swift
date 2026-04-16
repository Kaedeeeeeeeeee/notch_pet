import Foundation

/// Drives ambient pet behaviors: walking, pecking, dancing, etc.
/// Called each TimeService tick (~1Hz). The engine decides when the pet
/// should start a new behavior and advances walking movement.
@MainActor
final class PetBehaviorEngine {
    private var nextBehaviorAt: Date = Date().addingTimeInterval(3)
    private var behaviorEndAt: Date = .distantPast

    /// Movement range: ±130px from center (room is 540 wide).
    private static let maxX: CGFloat = 130
    /// Walking speed in points per second, personality-adjusted.
    private static let baseSpeed: CGFloat = 40

    func tick(petState: PetState, dt: TimeInterval) {
        guard petState.canInteract else { return }
        guard petState.stage != .egg else { return }

        let now = Date()

        switch petState.activeBehavior {
        case .actionFeedback:
            // Don't interrupt user-triggered animations
            return

        case .walking(let targetX):
            advanceWalk(petState: petState, targetX: targetX, dt: dt)

        case .performing:
            // One-shot animations: wait for them to end
            if now >= behaviorEndAt {
                petState.activeBehavior = .idle
            }

        case .idle:
            // Maybe start a new behavior
            if now >= nextBehaviorAt {
                startRandomBehavior(petState: petState)
            }
        }
    }

    // MARK: - Walking

    private func advanceWalk(petState: PetState, targetX: CGFloat, dt: TimeInterval) {
        let speed = Self.walkSpeed(for: petState.personality)
        let dx = speed * CGFloat(dt)
        let direction: CGFloat = targetX > petState.petX ? 1 : -1

        petState.facingRight = direction > 0
        petState.petX += direction * dx

        // Arrived?
        if abs(petState.petX - targetX) < dx + 1 {
            petState.petX = targetX
            petState.activeBehavior = .idle
            armNextBehavior(petState: petState, minDelay: 2, maxDelay: 5)
        }
    }

    private static func walkSpeed(for personality: PersonalityTrait?) -> CGFloat {
        switch personality {
        case .cheerful:   return baseSpeed * 1.3
        case .lazy:       return baseSpeed * 0.6
        case .grumpy:     return baseSpeed * 1.1
        case .shy:        return baseSpeed * 0.8
        case .aloof:      return baseSpeed * 0.9
        case .gluttonous: return baseSpeed * 0.95
        case nil:         return baseSpeed
        }
    }

    // MARK: - Behavior selection

    private func startRandomBehavior(petState: PetState) {
        let roll = Double.random(in: 0..<1)
        let weights = Self.behaviorWeights(for: petState.personality)

        var cumulative: Double = 0
        for (behavior, weight) in weights {
            cumulative += weight
            if roll < cumulative {
                startBehavior(behavior, petState: petState)
                return
            }
        }
        // Fallback: just idle longer
        armNextBehavior(petState: petState, minDelay: 3, maxDelay: 6)
    }

    private func startBehavior(_ behavior: AmbientBehavior, petState: PetState) {
        switch behavior {
        case .walk:
            let targetX = CGFloat.random(in: -Self.maxX...Self.maxX)
            petState.activeBehavior = .walking(targetX: targetX)

        case .peck:
            playPerforming(.peck, petState: petState, frames: 3)
        case .flap:
            playPerforming(.flap, petState: petState, frames: 3)
        case .dance:
            playPerforming(.dance, petState: petState, frames: 4)
        case .stretch:
            playPerforming(.stretch, petState: petState, frames: 3)
        case .sit:
            // Sit is longer — hold for ~3s
            petState.activeBehavior = .performing(.sit)
            behaviorEndAt = Date().addingTimeInterval(3.0)
            armNextBehavior(petState: petState, minDelay: 4, maxDelay: 8)
        case .idle:
            armNextBehavior(petState: petState, minDelay: 2, maxDelay: 5)
        }
    }

    private func playPerforming(_ mode: PetMode, petState: PetState, frames: Int) {
        petState.activeBehavior = .performing(mode)
        let fps = Self.fps(for: petState.personality)
        let duration = Double(frames) / fps * 2  // play ~2 cycles
        behaviorEndAt = Date().addingTimeInterval(duration)
        armNextBehavior(petState: petState, minDelay: 3, maxDelay: 7)
    }

    private func armNextBehavior(petState: PetState, minDelay: Double, maxDelay: Double) {
        nextBehaviorAt = Date().addingTimeInterval(.random(in: minDelay...maxDelay))
    }

    private static func fps(for personality: PersonalityTrait?) -> Double {
        switch personality {
        case .cheerful:            return 7
        case .lazy:                return 4
        case .shy, .aloof:         return 5
        case .grumpy, .gluttonous: return 6
        case nil:                  return 6
        }
    }

    // MARK: - Personality-weighted behavior selection

    private enum AmbientBehavior {
        case walk, peck, flap, dance, stretch, sit, idle
    }

    private static func behaviorWeights(for personality: PersonalityTrait?) -> [(AmbientBehavior, Double)] {
        // Weights should sum to ~1.0
        switch personality {
        case .cheerful:
            return [(.walk, 0.25), (.dance, 0.20), (.flap, 0.15), (.peck, 0.10),
                    (.stretch, 0.05), (.sit, 0.05), (.idle, 0.20)]
        case .lazy:
            return [(.sit, 0.30), (.walk, 0.10), (.peck, 0.05), (.stretch, 0.10),
                    (.dance, 0.05), (.flap, 0.05), (.idle, 0.35)]
        case .gluttonous:
            return [(.peck, 0.30), (.walk, 0.20), (.dance, 0.05), (.flap, 0.05),
                    (.stretch, 0.05), (.sit, 0.10), (.idle, 0.25)]
        case .shy:
            return [(.sit, 0.25), (.walk, 0.10), (.peck, 0.10), (.stretch, 0.05),
                    (.dance, 0.05), (.flap, 0.05), (.idle, 0.40)]
        case .aloof:
            return [(.walk, 0.15), (.stretch, 0.20), (.sit, 0.15), (.peck, 0.05),
                    (.dance, 0.05), (.flap, 0.05), (.idle, 0.35)]
        case .grumpy:
            return [(.walk, 0.30), (.peck, 0.10), (.flap, 0.10), (.dance, 0.05),
                    (.stretch, 0.05), (.sit, 0.10), (.idle, 0.30)]
        case nil:
            return [(.walk, 0.20), (.peck, 0.15), (.dance, 0.10), (.flap, 0.10),
                    (.stretch, 0.10), (.sit, 0.10), (.idle, 0.25)]
        }
    }
}
