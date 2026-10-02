import SwiftUI

/// Block 6: transient animation layered on top of `PetView` when the
/// user feeds or plays. Driven by `petState.actionAnimation`, which is
/// set for 900ms by the corresponding `PetState` action method.
///
/// - `.eating`: a small rice-ball sprite drops from the top of the pet
///   area, settles at the pet's mouth, then fades.
/// - `.playing`: a bouncing red ball next to the pet.
///
/// Implemented as pure SwiftUI — no new spritesheet tags — so it doesn't
/// balloon the Aseprite build. The Pet sprite itself is not swapped; we
/// nudge it with a small offset animation for feedback.
struct ActionAnimationOverlay: View {
    let animation: ActionAnimation
    let petSize: CGFloat

    var body: some View {
        switch animation {
        case .eating:
            EatingAnimation(petSize: petSize)
        case .playing:
            PlayingAnimation(petSize: petSize)
        case .medicine:
            FloatingCueAnimation(kind: .pill, petSize: petSize, x: petSize * 0.22)
        case .pooping:
            FloatingCueAnimation(kind: .waves, petSize: petSize, x: 0)
        case .cleaning:
            FloatingCueAnimation(kind: .sparkles, petSize: petSize, x: -petSize * 0.20)
        case .discipline:
            FloatingCueAnimation(kind: .exclamation, petSize: petSize, x: 0)
        case .toiletSuccess:
            FloatingCueAnimation(kind: .toilet, petSize: petSize, x: 0)
        case .feedRejected:
            FloatingCueAnimation(kind: .xmark, petSize: petSize, x: petSize * 0.20)
        case .hatch:
            FloatingCueAnimation(kind: .crack, petSize: petSize, x: 0)
        case .stageUp:
            FloatingCueAnimation(kind: .stageSparkles, petSize: petSize, x: 0)
        }
    }
}

/// Persistent warning shown while the pet can still be taken to the
/// toilet. Separate from `ActionAnimationOverlay` because it lasts until
/// either the user responds or the warning window expires.
struct NeedsPoopOverlay: View {
    let petSize: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: false)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let bob = CGFloat(sin(t * (2 * .pi / 0.55))) * 3
            PixelCue(kind: .waves, size: petSize * 0.30)
                .offset(x: petSize * 0.30, y: -petSize * 0.26 + bob)
        }
        .allowsHitTesting(false)
    }
}

private struct FloatingCueAnimation: View {
    let kind: PixelCue.Kind
    let petSize: CGFloat
    let x: CGFloat
    @State private var phase: CGFloat = 0

    var body: some View {
        PixelCue(kind: kind, size: petSize * cueScale)
            .offset(
                x: x + wobbleX,
                y: -petSize * 0.22 - phase * petSize * 0.20
            )
            .opacity(phase < 0.78 ? 1 : 1 - (phase - 0.78) / 0.22)
            .scaleEffect(1 + phase * 0.16)
            .onAppear {
                withAnimation(.easeOut(duration: kind.longLived ? 1.2 : 0.8)) {
                    phase = 1
                }
            }
            .allowsHitTesting(false)
    }

    private var cueScale: CGFloat {
        switch kind {
        case .stageSparkles, .crack: return 0.46
        case .toilet: return 0.34
        default: return 0.30
        }
    }

    private var wobbleX: CGFloat {
        switch kind {
        case .exclamation, .xmark:
            return phase < 0.6 ? sin(phase * .pi * 8) * 4 : 0
        default:
            return 0
        }
    }
}

private struct PixelCue: View {
    enum Kind {
        case pill, waves, sparkles, exclamation, toilet, xmark, crack, stageSparkles

        var longLived: Bool {
            self == .crack || self == .stageSparkles
        }
    }

    let kind: Kind
    let size: CGFloat

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, canvasSize in
            let gridSide = 12
            let pixel = min(canvasSize.width, canvasSize.height) / CGFloat(gridSide)
            let ox = (canvasSize.width - pixel * CGFloat(gridSide)) / 2
            let oy = (canvasSize.height - pixel * CGFloat(gridSide)) / 2

            for (col, row, cell) in Self.cells(for: kind) {
                guard let color = Self.color(for: cell, kind: kind) else { continue }
                let rect = CGRect(
                    x: ox + CGFloat(col) * pixel,
                    y: oy + CGFloat(row) * pixel,
                    width: pixel,
                    height: pixel
                )
                gc.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }

    private static func color(for cell: Int, kind: Kind) -> Color? {
        switch cell {
        case 1: return Color(red: 0.20, green: 0.12, blue: 0.08)
        case 2:
            switch kind {
            case .pill: return Color(red: 0.96, green: 0.25, blue: 0.30)
            case .waves, .toilet: return Color(red: 0.48, green: 0.78, blue: 0.95)
            case .exclamation, .xmark: return Color(red: 1.00, green: 0.42, blue: 0.14)
            case .crack: return Color(red: 1.00, green: 0.92, blue: 0.64)
            case .sparkles, .stageSparkles: return Color.white
            }
        case 3:
            switch kind {
            case .pill: return Color(red: 0.98, green: 0.98, blue: 0.95)
            case .toilet: return Color(red: 0.92, green: 0.96, blue: 0.95)
            case .crack: return Color(red: 0.62, green: 0.42, blue: 0.20)
            default: return Color(red: 1.0, green: 0.78, blue: 0.30)
            }
        default:
            return nil
        }
    }

    private static func unpack(_ shape: [[Int]]) -> [(Int, Int, Int)] {
        var out: [(Int, Int, Int)] = []
        for (row, line) in shape.enumerated() {
            for (col, cell) in line.enumerated() where cell != 0 {
                out.append((col, row, cell))
            }
        }
        return out
    }

    private static func cells(for kind: Kind) -> [(Int, Int, Int)] {
        switch kind {
        case .pill:
            return unpack([
                [0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,1,1,1,1,1,1,0,0,0],
                [0,0,1,2,2,2,3,3,3,1,0,0],
                [0,1,2,2,2,2,3,3,3,3,1,0],
                [0,1,2,2,2,2,3,3,3,3,1,0],
                [0,0,1,2,2,2,3,3,3,1,0,0],
                [0,0,0,1,1,1,1,1,1,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,2,0,0,2,0,0,0],
                [0,0,0,0,2,2,2,0,2,2,2,0],
                [0,0,0,0,0,2,0,0,0,2,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0],
            ])
        case .waves:
            return unpack([
                [0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,2,2,0,0,2,2,0,0,2,2],
                [0,2,0,0,2,2,0,0,2,2,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,2,2,0,0,2,2,0,0,2,2],
                [0,2,0,0,2,2,0,0,2,2,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,2,2,0,0,0,0,0],
                [0,0,0,0,2,0,0,2,0,0,0,0],
                [0,0,0,0,0,2,2,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0],
            ])
        case .sparkles, .stageSparkles:
            return unpack([
                [0,0,0,0,0,2,0,0,0,0,0,0],
                [0,0,0,0,2,2,2,0,0,0,0,0],
                [0,0,0,0,0,2,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,2,0,0,0],
                [0,0,0,0,0,0,0,2,2,2,0,0],
                [0,0,2,0,0,0,0,0,2,0,0,0],
                [0,2,2,2,0,0,0,0,0,0,0,0],
                [0,0,2,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,2,0,0],
                [0,0,0,0,0,0,0,0,2,2,2,0],
                [0,0,0,0,0,0,0,0,0,2,0,0],
                [0,0,0,0,2,0,0,0,0,0,0,0],
            ])
        case .exclamation:
            return unpack([
                [0,0,0,0,1,1,1,1,0,0,0,0],
                [0,0,0,1,2,2,2,2,1,0,0,0],
                [0,0,0,1,2,2,2,2,1,0,0,0],
                [0,0,0,1,2,2,2,2,1,0,0,0],
                [0,0,0,0,1,2,2,1,0,0,0,0],
                [0,0,0,0,1,2,2,1,0,0,0,0],
                [0,0,0,0,0,1,1,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,1,1,1,1,0,0,0,0],
                [0,0,0,1,2,2,2,2,1,0,0,0],
                [0,0,0,1,2,2,2,2,1,0,0,0],
                [0,0,0,0,1,1,1,1,0,0,0,0],
            ])
        case .toilet:
            return unpack([
                [0,0,0,0,1,1,1,1,1,0,0,0],
                [0,0,0,1,3,3,3,3,3,1,0,0],
                [0,0,0,1,3,2,2,2,3,1,0,0],
                [0,0,0,1,3,2,2,2,3,1,0,0],
                [0,0,0,0,1,3,3,3,1,0,0,0],
                [0,0,0,0,0,1,3,1,0,0,0,0],
                [0,0,0,0,0,1,3,1,0,0,0,0],
                [0,0,0,0,1,3,3,3,1,0,0,0],
                [0,0,0,1,3,3,3,3,3,1,0,0],
                [0,0,0,1,1,1,1,1,1,1,0,0],
                [0,0,0,0,0,2,2,2,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0],
            ])
        case .xmark:
            return unpack([
                [0,0,1,1,0,0,0,0,1,1,0,0],
                [0,0,1,2,1,0,0,1,2,1,0,0],
                [0,0,0,1,2,1,1,2,1,0,0,0],
                [0,0,0,0,1,2,2,1,0,0,0,0],
                [0,0,0,0,1,2,2,1,0,0,0,0],
                [0,0,0,1,2,1,1,2,1,0,0,0],
                [0,0,1,2,1,0,0,1,2,1,0,0],
                [0,0,1,1,0,0,0,0,1,1,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,3,3,0,0,0,0,0],
                [0,0,0,0,3,0,0,3,0,0,0,0],
                [0,0,0,0,0,3,3,0,0,0,0,0],
            ])
        case .crack:
            return unpack([
                [0,0,0,0,1,1,1,1,0,0,0,0],
                [0,0,0,1,2,2,2,2,1,0,0,0],
                [0,0,1,2,2,3,2,2,2,1,0,0],
                [0,1,2,2,3,0,3,2,2,2,1,0],
                [0,1,2,3,0,0,0,3,2,2,1,0],
                [0,1,2,2,3,0,3,2,2,2,1,0],
                [0,0,1,2,2,3,2,2,2,1,0,0],
                [0,0,0,1,2,2,2,2,1,0,0,0],
                [0,0,0,0,1,1,1,1,0,0,0,0],
                [0,0,2,0,0,0,0,0,0,2,0,0],
                [0,2,2,2,0,0,0,0,2,2,2,0],
                [0,0,2,0,0,0,0,0,0,2,0,0],
            ])
        }
    }
}

// MARK: - Eating (falling rice ball)

private struct EatingAnimation: View {
    let petSize: CGFloat
    @State private var phase: CGFloat = 0  // 0 → 1 over the animation

    var body: some View {
        RiceBallPixel(size: petSize * 0.22)
            .offset(
                x: 0,
                y: phase < 0.5
                    ? -petSize * 0.4 * (1 - phase / 0.5)
                    : 0
            )
            .opacity(phase < 0.85 ? 1.0 : 1.0 - (phase - 0.85) / 0.15)
            .onAppear {
                withAnimation(.easeIn(duration: 0.45)) {
                    phase = 0.55
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    withAnimation(.easeOut(duration: 0.45)) {
                        phase = 1.0
                    }
                }
            }
    }
}

/// Tiny rice-ball onigiri sprite — white rice triangle with a dark nori
/// strip at the base. 12x12 logical pixels.
private struct RiceBallPixel: View {
    let size: CGFloat

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, canvasSize in
            let gridSide = 12
            let pixel = min(canvasSize.width, canvasSize.height) / CGFloat(gridSide)
            let ox = (canvasSize.width - pixel * CGFloat(gridSide)) / 2
            let oy = (canvasSize.height - pixel * CGFloat(gridSide)) / 2

            let outline = Color(red: 0.22, green: 0.14, blue: 0.08)
            let rice    = Color(red: 0.98, green: 0.97, blue: 0.92)
            let highlight = Color.white
            let nori    = Color(red: 0.18, green: 0.22, blue: 0.14)

            for (col, row, cell) in Self.cells {
                let c: Color
                switch cell {
                case 1: c = outline
                case 2: c = rice
                case 3: c = highlight
                case 4: c = nori
                default: continue
                }
                let rect = CGRect(
                    x: ox + CGFloat(col) * pixel,
                    y: oy + CGFloat(row) * pixel,
                    width: pixel,
                    height: pixel
                )
                gc.fill(Path(rect), with: .color(c))
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }

    private static let cells: [(Int, Int, Int)] = {
        let shape: [[Int]] = [
            [0,0,0,0,0,1,1,0,0,0,0,0],
            [0,0,0,0,1,2,2,1,0,0,0,0],
            [0,0,0,1,2,3,2,2,1,0,0,0],
            [0,0,0,1,2,2,2,2,1,0,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
            [0,1,2,2,2,2,2,2,2,2,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,2,2,2,2,2,2,2,2,1,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0],
        ]
        var out: [(Int, Int, Int)] = []
        for (row, line) in shape.enumerated() {
            for (col, cell) in line.enumerated() where cell != 0 {
                out.append((col, row, cell))
            }
        }
        return out
    }()
}

// MARK: - Playing (bouncing ball)

private struct PlayingAnimation: View {
    let petSize: CGFloat
    @State private var bounce: CGFloat = 0  // current vertical offset

    var body: some View {
        BallPixel(size: petSize * 0.22)
            .offset(
                x: petSize * 0.28,
                y: bounce
            )
            .onAppear {
                // Two keyframed bounces via chained implicit animations
                withAnimation(.easeOut(duration: 0.20)) {
                    bounce = -petSize * 0.18
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    withAnimation(.easeIn(duration: 0.18)) { bounce = 0 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        bounce = -petSize * 0.12
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
                    withAnimation(.easeIn(duration: 0.20)) { bounce = 0 }
                }
            }
    }
}

/// Small red ball, 12x12 logical pixels.
private struct BallPixel: View {
    let size: CGFloat

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, canvasSize in
            let gridSide = 12
            let pixel = min(canvasSize.width, canvasSize.height) / CGFloat(gridSide)
            let ox = (canvasSize.width - pixel * CGFloat(gridSide)) / 2
            let oy = (canvasSize.height - pixel * CGFloat(gridSide)) / 2

            let outline  = Color(red: 0.25, green: 0.05, blue: 0.08)
            let red      = Color(red: 0.95, green: 0.25, blue: 0.30)
            let highlight = Color(red: 1.00, green: 0.75, blue: 0.75)

            for (col, row, cell) in Self.cells {
                let c: Color
                switch cell {
                case 1: c = outline
                case 2: c = red
                case 3: c = highlight
                default: continue
                }
                let rect = CGRect(
                    x: ox + CGFloat(col) * pixel,
                    y: oy + CGFloat(row) * pixel,
                    width: pixel,
                    height: pixel
                )
                gc.fill(Path(rect), with: .color(c))
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }

    private static let cells: [(Int, Int, Int)] = {
        let shape: [[Int]] = [
            [0,0,0,1,1,1,1,1,0,0,0,0],
            [0,0,1,2,2,2,2,2,1,0,0,0],
            [0,1,2,3,3,2,2,2,2,1,0,0],
            [0,1,2,3,3,2,2,2,2,1,0,0],
            [1,2,2,2,2,2,2,2,2,2,1,0],
            [1,2,2,2,2,2,2,2,2,2,1,0],
            [1,2,2,2,2,2,2,2,2,2,1,0],
            [1,2,2,2,2,2,2,2,2,2,1,0],
            [0,1,2,2,2,2,2,2,2,1,0,0],
            [0,1,2,2,2,2,2,2,2,1,0,0],
            [0,0,1,2,2,2,2,2,1,0,0,0],
            [0,0,0,1,1,1,1,1,0,0,0,0],
        ]
        var out: [(Int, Int, Int)] = []
        for (row, line) in shape.enumerated() {
            for (col, cell) in line.enumerated() where cell != 0 {
                out.append((col, row, cell))
            }
        }
        return out
    }()
}
