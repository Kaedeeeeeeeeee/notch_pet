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
        case .medicine, .pooping, .cleaning:
            // These actions now use sprite-based pet animations
            // (PetMode.medic / .poopAct / .cleanAct) — no overlay needed.
            EmptyView()
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
