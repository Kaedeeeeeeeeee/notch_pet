import SwiftUI

/// Small pixel-art poop pile rendered on the room floor when
/// `petState.poops > 0`. 12x12 grid so it reads at the Tamagotchi-esque
/// small footprint without stealing focus from the pet sprite.
struct PoopView: View {
    let size: CGFloat

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, canvasSize in
            let gridSide = 12
            let pixel = min(canvasSize.width, canvasSize.height) / CGFloat(gridSide)
            let ox = (canvasSize.width - pixel * CGFloat(gridSide)) / 2
            let oy = (canvasSize.height - pixel * CGFloat(gridSide)) / 2

            let outline   = Color(red: 0.22, green: 0.14, blue: 0.08)
            let body      = Color(red: 0.58, green: 0.36, blue: 0.18)
            let highlight = Color(red: 0.78, green: 0.52, blue: 0.26)

            for (col, row, cell) in Self.cells {
                let color: Color
                switch cell {
                case 1: color = outline
                case 2: color = body
                case 3: color = highlight
                default: continue
                }
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

    /// 12x12 stacked-swirl poop pile. 0=transparent 1=outline 2=body 3=highlight
    private static let cells: [(Int, Int, Int)] = {
        let shape: [[Int]] = [
            [0,0,0,0,0,1,1,0,0,0,0,0],
            [0,0,0,0,1,2,2,1,0,0,0,0],
            [0,0,0,1,2,3,2,2,1,0,0,0],
            [0,0,0,1,2,2,2,2,1,0,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
            [0,1,2,2,3,2,2,2,2,2,1,0],
            [0,1,2,2,2,2,2,2,2,2,1,0],
            [1,2,2,2,2,2,2,2,2,2,2,1],
            [1,2,3,2,2,2,2,2,2,2,2,1],
            [1,2,2,2,2,2,2,2,2,2,2,1],
            [0,1,1,1,1,1,1,1,1,1,1,0],
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
