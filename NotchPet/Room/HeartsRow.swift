import SwiftUI

/// Discrete-heart vitals display. Block 6 replaces the Block 2 continuous
/// `StatusBar` bars with a 4-heart row per stat, matching the Tamagotchi
/// "4 hearts, feed 4 times" reading. Each heart is a 10x10 pixel sprite
/// drawn in SwiftUI Canvas.
struct HeartsRow: View {
    let label: String
    let filled: Int
    let max: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
            }
            HStack(spacing: 3) {
                ForEach(0..<max, id: \.self) { i in
                    HeartPixel(
                        filled: i < filled,
                        tint: tint,
                        side: 12
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// One small heart sprite, 10x10 logical pixel grid inside `side`×`side`
/// points. Filled hearts paint the full shape with `tint`; empty hearts
/// paint only the outline (subdued).
private struct HeartPixel: View {
    let filled: Bool
    let tint: Color
    let side: CGFloat

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, size in
            let gridSide = 10
            let pixel = min(size.width, size.height) / CGFloat(gridSide)
            let ox = (size.width - pixel * CGFloat(gridSide)) / 2
            let oy = (size.height - pixel * CGFloat(gridSide)) / 2

            for (col, row, cell) in Self.heartCells {
                let color: Color
                switch cell {
                case 1:  // outline
                    color = filled ? Color(red: 0.35, green: 0.08, blue: 0.10) : .white.opacity(0.25)
                case 2:  // fill
                    color = filled ? tint : .clear
                case 3:  // highlight
                    color = filled ? .white.opacity(0.85) : .clear
                default:
                    continue
                }
                if color == .clear { continue }
                let rect = CGRect(
                    x: ox + CGFloat(col) * pixel,
                    y: oy + CGFloat(row) * pixel,
                    width: pixel,
                    height: pixel
                )
                gc.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: side, height: side)
        .drawingGroup()
    }

    /// 10x10 heart pixel grid. 0=transparent 1=outline 2=fill 3=highlight
    private static let heartCells: [(Int, Int, Int)] = {
        let shape: [[Int]] = [
            [0,1,1,0,0,0,0,1,1,0],
            [1,2,2,1,0,0,1,2,2,1],
            [1,2,3,2,1,1,2,3,2,1],
            [1,2,2,2,2,2,2,2,2,1],
            [1,2,2,2,2,2,2,2,2,1],
            [0,1,2,2,2,2,2,2,1,0],
            [0,0,1,2,2,2,2,1,0,0],
            [0,0,0,1,2,2,1,0,0,0],
            [0,0,0,0,1,1,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0],
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
