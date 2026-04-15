import SwiftUI

/// Pixel-art placeholder pet drawn at runtime via SwiftUI Canvas.
/// MVP Block 1: a 16x16 "chick" that breathes and blinks across 4 frames.
/// Block 2 adds sleeping / hungry variants tied to PetState.
/// Real Aseprite-exported spritesheets replace this in Block 4.
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

/// Pure function renderer. Separated out so we can unit test it and reuse
/// for the expanded RoomView at larger sizes.
enum PetRenderer {
    /// 16x16 logical pixel grid. Each cell maps to a square block in the canvas.
    static let gridSide: Int = 16

    static func draw(frame: Int, mode: PetMode, in gc: GraphicsContext, canvasSize: CGSize) {
        let side = min(canvasSize.width, canvasSize.height)
        let pixel = side / CGFloat(gridSide)
        let originX = (canvasSize.width - pixel * CGFloat(gridSide)) / 2
        let originY = (canvasSize.height - pixel * CGFloat(gridSide)) / 2

        // Breathing: even frames lift the body by 1 pixel. Blink on frame 6
        // when awake. Sleeping replaces blink with permanent closed eyes.
        let breathOffset = (frame / 2) % 2 == 0 ? 0 : -1
        let blink: Bool
        switch mode {
        case .idle, .hungry: blink = (frame == 6)
        case .sleeping:      blink = true
        }

        for (x, y, color) in petPixels(mode: mode, frame: frame, breathOffset: breathOffset, blink: blink) {
            let rect = CGRect(
                x: originX + CGFloat(x) * pixel,
                y: originY + CGFloat(y) * pixel,
                width: pixel,
                height: pixel
            )
            gc.fill(Path(rect), with: .color(color))
        }
    }

    /// Lays out the pet body in the 16x16 grid. Coordinates are top-left origin.
    private static func petPixels(mode: PetMode, frame: Int, breathOffset: Int, blink: Bool) -> [(Int, Int, Color)] {
        let body = Color(red: 1.00, green: 0.86, blue: 0.35)      // chick yellow
        let outline = Color(red: 0.35, green: 0.20, blue: 0.05)   // dark brown
        let beak = Color(red: 1.00, green: 0.55, blue: 0.10)      // orange
        let eye = Color(red: 0.10, green: 0.08, blue: 0.05)
        let cheek = Color(red: 1.00, green: 0.60, blue: 0.55)

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
                let yRaw = row + breathOffset
                guard yRaw >= 0, yRaw < 16 else { continue }
                switch cell {
                case 1: pixels.append((col, yRaw, body))
                case 2: pixels.append((col, yRaw, outline))
                default: break
                }
            }
        }

        // Eyes: closed line when blinking/sleeping, dot otherwise.
        let eyePositions: [(Int, Int)] = [(6, 5), (9, 5)]
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

        // Beak
        pixels.append((7, 7 + breathOffset, beak))
        pixels.append((8, 7 + breathOffset, beak))
        pixels.append((7, 8 + breathOffset, beak))
        pixels.append((8, 8 + breathOffset, beak))

        // Cheeks
        pixels.append((4, 7 + breathOffset, cheek))
        pixels.append((11, 7 + breathOffset, cheek))

        // Mode-specific overlays
        switch mode {
        case .idle:
            break
        case .hungry:
            // Blink an orange "!" above the head every other frame so it reads
            // as an attention cue.
            if (frame / 2) % 2 == 0 {
                let warn = Color(red: 1.0, green: 0.55, blue: 0.10)
                pixels.append((8, 1, warn))
                pixels.append((8, 2, warn))
                pixels.append((8, 3, warn))
            }
        case .sleeping:
            // A tiny Z floating to the upper-right.
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
}
