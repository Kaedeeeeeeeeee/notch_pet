import SwiftUI

/// Pixel-art icons for the three RoomView action buttons. Each icon is a
/// 16x16 grid rendered via SwiftUI Canvas, matching the chick sprite's
/// aesthetic so the whole popover feels one-piece.
struct ActionIconView: View {
    let kind: Kind
    let size: CGFloat

    enum Kind {
        case feed, play, rest
    }

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let pixel = side / CGFloat(Self.gridSide)
            let ox = (canvasSize.width - pixel * CGFloat(Self.gridSide)) / 2
            let oy = (canvasSize.height - pixel * CGFloat(Self.gridSide)) / 2

            for (x, y, color) in pixels(for: kind) {
                let rect = CGRect(
                    x: ox + CGFloat(x) * pixel,
                    y: oy + CGFloat(y) * pixel,
                    width: pixel,
                    height: pixel
                )
                gc.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }

    // MARK: - Grid

    private static let gridSide: Int = 16

    private func pixels(for kind: Kind) -> [(Int, Int, Color)] {
        switch kind {
        case .feed: return Self.feedPixels
        case .play: return Self.playPixels
        case .rest: return Self.restPixels
        }
    }

    // MARK: - Feed: rice bowl

    /// Cell legend for feed:
    /// 0 transparent  1 rice white  2 rice highlight  3 bowl outline
    /// 4 bowl interior light  5 bowl shadow
    private static let feedShape: [[Int]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,1,2,1,1,2,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,3,3,3,3,3,3,3,3,3,3,3,3,0,0],
        [0,3,4,4,4,4,4,4,4,4,4,4,4,4,3,0],
        [0,3,4,4,4,4,4,4,4,4,4,4,4,4,3,0],
        [0,3,5,5,4,4,4,4,4,4,4,4,5,5,3,0],
        [0,0,3,5,5,5,5,5,5,5,5,5,5,3,0,0],
        [0,0,0,3,3,5,5,5,5,5,5,3,3,0,0,0],
        [0,0,0,0,0,3,3,3,3,3,3,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    private static let feedPixels: [(Int, Int, Color)] = {
        let riceWhite    = Color(red: 0.98, green: 0.97, blue: 0.92)
        let riceHighlight = Color.white
        let bowlOutline  = Color(red: 0.22, green: 0.14, blue: 0.08)
        let bowlLight    = Color(red: 0.75, green: 0.55, blue: 0.35)
        let bowlShadow   = Color(red: 0.50, green: 0.32, blue: 0.18)

        func color(_ cell: Int) -> Color? {
            switch cell {
            case 1: return riceWhite
            case 2: return riceHighlight
            case 3: return bowlOutline
            case 4: return bowlLight
            case 5: return bowlShadow
            default: return nil
            }
        }

        var out: [(Int, Int, Color)] = []
        for (row, line) in feedShape.enumerated() {
            for (col, cell) in line.enumerated() {
                if let c = color(cell) {
                    out.append((col, row, c))
                }
            }
        }
        return out
    }()

    // MARK: - Play: balloon

    /// Cell legend for play:
    /// 0 transparent  1 balloon red  2 highlight  3 shadow
    /// 4 knot  5 string
    private static let playShape: [[Int]] = [
        [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,1,1,2,2,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,2,2,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,2,1,1,1,1,1,1,1,1,1,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,1,3,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,1,3,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,3,0,0,0,0,0],
        [0,0,0,0,0,0,4,4,4,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,5,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,5,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    private static let playPixels: [(Int, Int, Color)] = {
        let bright   = Color(red: 1.00, green: 0.32, blue: 0.38)
        let highlight = Color(red: 1.00, green: 0.85, blue: 0.85)
        let shadow   = Color(red: 0.70, green: 0.12, blue: 0.18)
        let knot     = Color(red: 0.60, green: 0.10, blue: 0.15)
        let string   = Color(red: 0.82, green: 0.82, blue: 0.82)

        func color(_ cell: Int) -> Color? {
            switch cell {
            case 1: return bright
            case 2: return highlight
            case 3: return shadow
            case 4: return knot
            case 5: return string
            default: return nil
            }
        }

        var out: [(Int, Int, Color)] = []
        for (row, line) in playShape.enumerated() {
            for (col, cell) in line.enumerated() {
                if let c = color(cell) {
                    out.append((col, row, c))
                }
            }
        }
        return out
    }()

    // MARK: - Rest: stylized Zzz

    /// Cell legend for rest:
    /// 0 transparent  1 Z blue  2 Z highlight
    private static let restShape: [[Int]] = [
        [0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,2,1,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,1,2,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,1,1,1,1,1,1,2,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    private static let restPixels: [(Int, Int, Color)] = {
        let blue      = Color(red: 0.50, green: 0.70, blue: 1.00)
        let highlight = Color(red: 0.85, green: 0.92, blue: 1.00)

        func color(_ cell: Int) -> Color? {
            switch cell {
            case 1: return blue
            case 2: return highlight
            default: return nil
            }
        }

        var out: [(Int, Int, Color)] = []
        for (row, line) in restShape.enumerated() {
            for (col, cell) in line.enumerated() {
                if let c = color(cell) {
                    out.append((col, row, c))
                }
            }
        }
        return out
    }()
}
