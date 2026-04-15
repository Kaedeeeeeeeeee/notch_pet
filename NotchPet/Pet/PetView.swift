import SwiftUI

/// Pixel-art placeholder pet drawn at runtime via SwiftUI Canvas.
///
/// Block 1 introduced the idle chick, Block 2 added hungry/sleeping moods,
/// Block 3 adds stage-specific variants (egg, child, adult, elder, departed)
/// and a personality-driven tint. Real Aseprite-exported spritesheets
/// replace this in Block 4.
struct PetView: View {
    /// Target output side in points. The pet is drawn square.
    let size: CGFloat
    @ObservedObject var petState: PetState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 6.0, paused: false)) { context in
            Canvas(rendersAsynchronously: false) { gc, canvasSize in
                PetRenderer.draw(
                    frame: Self.frameIndex(at: context.date),
                    mode: Self.mode(for: petState),
                    stage: petState.stage,
                    personality: petState.personality,
                    in: gc,
                    canvasSize: canvasSize
                )
            }
            .frame(width: size, height: size)
            .drawingGroup()
        }
    }

    private static func frameIndex(at date: Date) -> Int {
        let t = Int(date.timeIntervalSinceReferenceDate * 6)
        return ((t % 8) + 8) % 8
    }

    private static func mode(for state: PetState) -> PetMode {
        if state.stage == .egg { return .idle }
        if state.isAsleep { return .sleeping }
        if state.hunger < 0.25 { return .hungry }
        return .idle
    }
}

/// The visual states the placeholder pet can render. Block 3 will add more
/// (sick, sad, excited) once personality lands.
enum PetMode {
    case idle
    case hungry
    case sleeping
}

/// Pure function renderer.
enum PetRenderer {
    /// 16x16 logical pixel grid. Each cell maps to a square block in the canvas.
    static let gridSide: Int = 16

    static func draw(
        frame: Int,
        mode: PetMode,
        stage: LifecycleStage,
        personality: PersonalityTrait?,
        in gc: GraphicsContext,
        canvasSize: CGSize
    ) {
        let side = min(canvasSize.width, canvasSize.height)
        let pixel = side / CGFloat(gridSide)
        let originX = (canvasSize.width - pixel * CGFloat(gridSide)) / 2
        let originY = (canvasSize.height - pixel * CGFloat(gridSide)) / 2

        let pixels: [(Int, Int, Color)]
        switch stage {
        case .egg:
            pixels = eggPixels(frame: frame)
        case .child, .adult, .elder:
            pixels = chickPixels(
                mode: mode,
                frame: frame,
                stage: stage,
                personality: personality
            )
        case .departed:
            pixels = departedPixels(frame: frame)
        }

        for (x, y, color) in pixels {
            let rect = CGRect(
                x: originX + CGFloat(x) * pixel,
                y: originY + CGFloat(y) * pixel,
                width: pixel,
                height: pixel
            )
            gc.fill(Path(rect), with: .color(color))
        }
    }

    // MARK: - Egg

    private static func eggPixels(frame: Int) -> [(Int, Int, Color)] {
        // A speckled egg that wiggles every few frames — "life inside".
        let shell = Color(red: 1.00, green: 0.97, blue: 0.82)
        let outline = Color(red: 0.45, green: 0.35, blue: 0.10)
        let speckle = Color(red: 0.80, green: 0.55, blue: 0.30)
        let wiggle = (frame / 3) % 2 == 0 ? 0 : 1
        let shape: [[Int]] = [
            [0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0],
            [0,0,0,0,0,2,1,1,1,2,0,0,0,0,0,0],
            [0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0],
            [0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0],
            [0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0],
            [0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0],
            [0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0],
            [0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        ]
        var pixels: [(Int, Int, Color)] = []
        for (row, line) in shape.enumerated() {
            for (col, cell) in line.enumerated() {
                let y = row
                let x = col + wiggle
                switch cell {
                case 1: pixels.append((x, y, shell))
                case 2: pixels.append((x, y, outline))
                default: break
                }
            }
        }
        // Speckles
        pixels.append((6 + wiggle, 5, speckle))
        pixels.append((9 + wiggle, 8, speckle))
        pixels.append((5 + wiggle, 10, speckle))
        return pixels
    }

    // MARK: - Chick (child / adult / elder)

    private static func chickPixels(
        mode: PetMode,
        frame: Int,
        stage: LifecycleStage,
        personality: PersonalityTrait?
    ) -> [(Int, Int, Color)] {
        let tint: (r: Double, g: Double, b: Double) = personality?.bodyTint ?? (r: 1.0, g: 1.0, b: 1.0)
        let dim: Double = stage == .elder ? 0.85 : 1.0
        let body = Color(
            red: clamp(1.00 * tint.r * dim),
            green: clamp(0.86 * tint.g * dim),
            blue: clamp(0.35 * tint.b * dim)
        )
        let outline = Color(red: 0.35, green: 0.20, blue: 0.05)
        let beak = Color(red: 1.00, green: 0.55, blue: 0.10)
        let eye = Color(red: 0.10, green: 0.08, blue: 0.05)
        let cheek = Color(red: 1.00, green: 0.60, blue: 0.55)

        let breathOffset = (frame / 2) % 2 == 0 ? 0 : -1
        let blink: Bool
        switch mode {
        case .idle, .hungry: blink = (frame == 6)
        case .sleeping:      blink = true
        }

        // Child is a touch smaller; adult is the full 16x16 body. We use a
        // row offset to shrink vertically for the child.
        let childShrink = stage == .child ? 1 : 0

        let shape: [[Int]] = [
            [0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0],
            [0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0],
            [0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
            [0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
            [0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
            [0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0],
            [0,0,0,0,2,2,1,1,1,2,2,0,0,0,0,0],
            [0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0],
            [0,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0],
            [0,0,0,0,2,2,0,0,0,2,2,0,0,0,0,0],
        ]

        var pixels: [(Int, Int, Color)] = []
        for (row, line) in shape.enumerated() {
            for (col, cell) in line.enumerated() {
                let yRaw = row + breathOffset + childShrink
                guard yRaw >= 0, yRaw < 16 else { continue }
                switch cell {
                case 1: pixels.append((col, yRaw, body))
                case 2: pixels.append((col, yRaw, outline))
                default: break
                }
            }
        }

        let eyePositions: [(Int, Int)] = [(6, 5 + childShrink), (9, 5 + childShrink)]
        if blink {
            for (x, y) in eyePositions {
                pixels.append((x, y + breathOffset, outline))
                pixels.append((x + 1, y + breathOffset, outline))
            }
        } else {
            for (x, y) in eyePositions {
                pixels.append((x, y + breathOffset, eye))
            }
        }

        pixels.append((7, 7 + breathOffset + childShrink, beak))
        pixels.append((8, 7 + breathOffset + childShrink, beak))
        pixels.append((7, 8 + breathOffset + childShrink, beak))
        pixels.append((8, 8 + breathOffset + childShrink, beak))

        pixels.append((4, 7 + breathOffset + childShrink, cheek))
        pixels.append((11, 7 + breathOffset + childShrink, cheek))

        switch mode {
        case .idle:
            break
        case .hungry:
            if (frame / 2) % 2 == 0 {
                let warn = Color(red: 1.0, green: 0.55, blue: 0.10)
                pixels.append((8, 1, warn))
                pixels.append((8, 2, warn))
                pixels.append((8, 3, warn))
            }
        case .sleeping:
            let z = Color.white
            pixels.append((11, 0, z))
            pixels.append((12, 0, z))
            pixels.append((13, 0, z))
            pixels.append((12, 1, z))
            pixels.append((11, 2, z))
            pixels.append((12, 2, z))
            pixels.append((13, 2, z))
        }

        return pixels
    }

    // MARK: - Departed

    private static func departedPixels(frame: Int) -> [(Int, Int, Color)] {
        // A dim silhouette that pulses so the farewell is visible.
        let alpha: Double = (frame / 2) % 2 == 0 ? 0.5 : 0.3
        let ghost = Color(red: 0.85, green: 0.80, blue: 0.70).opacity(alpha)
        let outline = Color.white.opacity(alpha * 0.7)
        let shape: [[Int]] = [
            [0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0],
            [0,0,0,0,2,1,1,1,1,1,2,0,0,0,0,0],
            [0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
            [0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
            [0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
            [0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,2,1,1,1,1,1,1,1,1,1,2,0,0,0],
            [0,0,0,2,1,1,1,1,1,1,1,2,0,0,0,0],
            [0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        ]
        var pixels: [(Int, Int, Color)] = []
        for (row, line) in shape.enumerated() {
            for (col, cell) in line.enumerated() {
                switch cell {
                case 1: pixels.append((col, row, ghost))
                case 2: pixels.append((col, row, outline))
                default: break
                }
            }
        }
        return pixels
    }

    private static func clamp(_ value: Double) -> Double {
        min(1.0, max(0.0, value))
    }
}
