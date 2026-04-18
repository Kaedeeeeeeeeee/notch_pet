import SwiftUI

/// Sprite-driven pet view. Fetches a `CGImage` from `PetSpriteLibrary`
/// each TimelineView tick and renders it as a SwiftUI `Image` with
/// nearest-neighbor interpolation so pixel edges stay crisp.
///
/// Each species has one shared base body; personality adds subtle
/// expression overlays (1-2px) and affects animation rhythm. Elder
/// uses a 0.85 opacity dim baked into the sprite.
struct PetView: View {
    let size: CGFloat
    @ObservedObject var petState: PetState
    /// When false the pet stays centred (used in the collapsed notch strip).
    var applyMovement: Bool = true

    /// Tracks the next time a personality micro-action should fire.
    @State private var nextMicroAt: Date = .distantFuture
    /// When set, overrides the normal mode with a micro-action for one cycle.
    @State private var activeMicro: PetMode? = nil

    private var animInterval: Double {
        1.0 / Self.fps(for: petState.personality)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: animInterval, paused: false)) { context in
            let frame = Self.frameIndex(at: context.date, personality: petState.personality)
            let resolved = resolveMode(at: context.date)

            let cg = PetSpriteLibrary.shared.frame(
                species: petState.species,
                stage: petState.stage,
                mode: resolved,
                personality: petState.personality,
                frameIndex: frame
            )

            Image(decorative: cg, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .scaleEffect(x: petState.facingRight ? 1 : -1, y: 1)
        }
        .offset(x: applyMovement ? petState.petX : 0)
        .animation(applyMovement ? .easeInOut(duration: 0.3) : nil, value: petState.petX)
        .onAppear { armMicro() }
    }

    /// Determine the effective mode, inserting micro-actions during idle.
    private func resolveMode(at date: Date) -> PetMode {
        let baseMode = Self.mode(for: petState)

        // If a micro-action is active and we're idle, show it
        if let micro = activeMicro, baseMode == .idle {
            let cycleDuration = Double(PetMode.microFrameCount) / Self.fps(for: petState.personality)
            if date.timeIntervalSince(nextMicroAt) > cycleDuration {
                DispatchQueue.main.async { activeMicro = nil; armMicro() }
            }
            return micro
        }

        // Schedule next micro-action trigger
        if baseMode == .idle, activeMicro == nil,
           date >= nextMicroAt,
           petState.stage == .adult || petState.stage == .elder,
           let micro = Self.microAction(for: petState.personality) {
            DispatchQueue.main.async { activeMicro = micro }
        }

        return baseMode
    }

    // MARK: - Micro-action scheduling

    private func armMicro() {
        let interval = Self.microInterval(for: petState.personality)
        nextMicroAt = Date().addingTimeInterval(interval)
    }

    /// Seconds between idle micro-action triggers per personality.
    private static func microInterval(for personality: PersonalityTrait?) -> TimeInterval {
        switch personality {
        case .cheerful, .gluttonous: return Double.random(in: 6...10)
        case .grumpy, .shy:          return Double.random(in: 12...18)
        case .aloof, .lazy:          return Double.random(in: 16...24)
        case nil:                    return 15
        }
    }

    /// The micro-action mode for a given personality.
    private static func microAction(for personality: PersonalityTrait?) -> PetMode? {
        switch personality {
        case .cheerful:   return .bounce
        case .shy:        return .hide
        case .aloof:      return .lookaway
        case .gluttonous: return .lick
        case .lazy:       return .yawn
        case .grumpy:     return .huff
        case nil:         return nil
        }
    }

    // MARK: - Frame timing

    /// Personality-specific animation FPS.
    private static func fps(for personality: PersonalityTrait?) -> Double {
        switch personality {
        case .cheerful:   return 7
        case .lazy:       return 4
        case .shy, .aloof: return 5
        case .grumpy, .gluttonous: return 6
        case nil:         return 6
        }
    }

    private static func frameIndex(at date: Date, personality: PersonalityTrait?) -> Int {
        let rate = fps(for: personality)
        let t = Int(date.timeIntervalSinceReferenceDate * rate)
        return ((t % 8) + 8) % 8
    }

    /// Mode priority (highest wins):
    ///   egg / departed → idle
    ///   asleep → sleeping
    ///   actionFeedback → eat/playAct/medic/poopAct/cleanAct
    ///   sick → sick
    ///   grumpy+angry → angry
    ///   walking → walk
    ///   performing → peck/flap/dance/stretch/sit
    ///   hovered → curious
    ///   happy → happy
    ///   hunger==0 → hungry
    ///   else idle
    static func mode(for state: PetState) -> PetMode {
        if state.stage == .egg || state.stage == .departed { return .idle }
        if state.isAsleep { return .sleeping }
        // Action feedback animations take priority
        switch state.activeBehavior {
        case .actionFeedback(let m): return m
        default: break
        }
        if state.sick { return .sick }
        if state.personality?.angerTriggerThreshold != nil,
           (state.hunger == 0 || state.happy == 0) {
            return .angry
        }
        // Behavior engine modes
        switch state.activeBehavior {
        case .walking: return .walk
        case .performing(let m): return m
        default: break
        }
        if state.isHovered { return .curious }
        if state.isHappy { return .happy }
        if state.hunger == 0 { return .hungry }
        return .idle
    }
}

/// The visual modes `PetView` can render.
enum PetMode: String {
    // Base state modes
    case idle, hungry, happy, sick, sleeping, curious, angry
    // Personality micro-actions
    case bounce, hide, lookaway, lick, yawn, huff
    // Ambient behaviors
    case walk, peck, flap, dance, stretch, sit
    // Action feedback
    case eat, playAct = "play_act", medic, poopAct = "poop_act", cleanAct = "clean_act"

    /// Tag name used in the Aseprite spritesheet.
    var tagName: String { rawValue }

    /// Frame count for short animation modes (micro-actions, behaviors, actions).
    static let microFrameCount: Int = 3
}
