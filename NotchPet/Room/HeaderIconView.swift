import SwiftUI

/// Multi-color pixel-art icons for the RoomView header bar (settings,
/// shop, coin). 12x12 grid, same aesthetic as ActionIconView.
struct HeaderIconView: View {
    let kind: Kind
    let size: CGFloat

    enum Kind {
        case settings, shop, coin, volume, shake, language
    }

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let pixel = side / CGFloat(Self.gridSide)
            let ox = (canvasSize.width - pixel * CGFloat(Self.gridSide)) / 2
            let oy = (canvasSize.height - pixel * CGFloat(Self.gridSide)) / 2

            for (x, y, color) in Self.pixels(for: kind) {
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

    private static let gridSide = 12

    private static func pixels(for kind: Kind) -> [(Int, Int, Color)] {
        switch kind {
        case .settings: return settingsPixels
        case .shop:     return shopPixels
        case .coin:     return coinPixels
        case .volume:   return volumePixels
        case .shake:    return shakePixels
        case .language: return languagePixels
        }
    }

    // MARK: - Settings gear

    /// 12x12 gear with 4 teeth and center hole.
    /// 0=transparent  1=outline  2=body  3=highlight
    private static let settingsShape: [[Int]] = [
        [0,0,0,1,1,0,0,1,1,0,0,0],
        [0,0,0,1,2,1,1,2,1,0,0,0],
        [0,0,1,2,2,2,2,2,2,1,0,0],
        [1,1,2,2,1,1,1,1,2,2,1,1],
        [1,2,2,1,0,0,0,0,1,2,2,1],
        [0,1,2,1,0,0,0,0,1,2,1,0],
        [0,1,2,1,0,0,0,0,1,2,1,0],
        [1,2,2,1,0,0,0,0,1,2,2,1],
        [1,1,2,2,1,1,1,1,2,2,1,1],
        [0,0,1,2,2,2,2,2,2,1,0,0],
        [0,0,0,1,2,1,1,2,1,0,0,0],
        [0,0,0,1,1,0,0,1,1,0,0,0],
    ]

    private static let settingsPixels: [(Int, Int, Color)] = {
        let outline = Color(red: 0.30, green: 0.30, blue: 0.32)
        let body    = Color(red: 0.62, green: 0.62, blue: 0.65)
        let hi      = Color(red: 0.82, green: 0.82, blue: 0.85)

        return build(settingsShape) {
            switch $0 {
            case 1: return outline
            case 2: return body
            case 3: return hi
            default: return nil
            }
        }
    }()

    // MARK: - Shop bag

    /// 12x12 shopping bag with handle.
    /// 0=transparent  1=outline  2=bag body  3=highlight  4=shadow
    private static let shopShape: [[Int]] = [
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,0,1,0,0,0,0,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,0,1,3,3,2,2,2,2,1,0,0],
        [0,0,1,3,2,2,2,2,2,1,0,0],
        [0,0,1,2,2,2,2,2,2,1,0,0],
        [0,0,1,2,2,2,2,2,2,1,0,0],
        [0,0,1,2,2,2,2,2,2,1,0,0],
        [0,0,1,2,2,2,2,2,4,1,0,0],
        [0,0,1,2,2,2,2,4,4,1,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    private static let shopPixels: [(Int, Int, Color)] = {
        let outline = Color(red: 0.20, green: 0.14, blue: 0.08)
        let body    = Color(red: 0.72, green: 0.55, blue: 0.35)
        let hi      = Color(red: 0.90, green: 0.75, blue: 0.52)
        let shadow  = Color(red: 0.50, green: 0.36, blue: 0.20)

        return build(shopShape) {
            switch $0 {
            case 1: return outline
            case 2: return body
            case 3: return hi
            case 4: return shadow
            default: return nil
            }
        }
    }()

    // MARK: - Coin

    /// 12x12 round coin with a C emboss.
    /// 0=transparent  1=outline  2=gold  3=highlight  4=emboss  5=shadow
    private static let coinShape: [[Int]] = [
        [0,0,0,1,1,1,1,1,1,0,0,0],
        [0,0,1,3,3,3,2,2,2,1,0,0],
        [0,1,3,2,2,2,2,2,2,5,1,0],
        [1,3,2,2,4,4,4,4,2,2,5,1],
        [1,3,2,4,2,2,2,2,2,2,5,1],
        [1,2,2,4,2,2,2,2,2,2,5,1],
        [1,2,2,4,2,2,2,2,2,5,2,1],
        [1,2,2,4,2,2,2,2,2,5,2,1],
        [1,2,2,2,4,4,4,4,5,2,2,1],
        [0,1,2,2,2,2,2,2,5,2,1,0],
        [0,0,1,2,2,2,5,5,2,1,0,0],
        [0,0,0,1,1,1,1,1,1,0,0,0],
    ]

    private static let coinPixels: [(Int, Int, Color)] = {
        let outline = Color(red: 0.22, green: 0.16, blue: 0.06)
        let gold    = Color(red: 0.85, green: 0.68, blue: 0.25)
        let hi      = Color(red: 1.00, green: 0.90, blue: 0.50)
        let emboss  = Color(red: 0.65, green: 0.50, blue: 0.15)
        let shadow  = Color(red: 0.60, green: 0.45, blue: 0.12)

        return build(coinShape) {
            switch $0 {
            case 1: return outline
            case 2: return gold
            case 3: return hi
            case 4: return emboss
            case 5: return shadow
            default: return nil
            }
        }
    }()

    // MARK: - Volume speaker

    /// 12x12 speaker with two sound-wave arcs.
    /// 0=transparent  1=outline  2=body  3=sound wave
    private static let volumeShape: [[Int]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,0,0,0],
        [0,0,1,1,2,2,1,0,0,3,0,0],
        [0,0,1,2,2,2,1,0,3,0,3,0],
        [0,0,1,2,2,2,1,0,0,3,0,0],
        [0,0,1,2,2,2,1,0,3,0,3,0],
        [0,0,1,1,2,2,1,0,0,3,0,0],
        [0,0,0,0,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    private static let volumePixels: [(Int, Int, Color)] = {
        let outline = Color(red: 0.25, green: 0.30, blue: 0.38)
        let body    = Color(red: 0.55, green: 0.70, blue: 0.85)
        let wave    = Color(red: 0.45, green: 0.75, blue: 0.55)

        return build(volumeShape) {
            switch $0 {
            case 1: return outline
            case 2: return body
            case 3: return wave
            default: return nil
            }
        }
    }()

    // MARK: - Shake vibration

    /// 12x12 phone-shape with motion lines on both sides.
    /// 0=transparent  1=outline  2=screen  3=motion line  4=button
    private static let shakeShape: [[Int]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0],
        [0,3,0,0,1,1,1,1,0,0,3,0],
        [0,0,3,0,1,2,2,1,0,3,0,0],
        [0,3,0,0,1,2,2,1,0,0,3,0],
        [0,0,0,0,1,2,2,1,0,0,0,0],
        [0,0,0,0,1,2,2,1,0,0,0,0],
        [0,0,0,0,1,2,2,1,0,0,0,0],
        [0,0,0,0,1,2,2,1,0,0,0,0],
        [0,3,0,0,1,2,2,1,0,0,3,0],
        [0,0,3,0,1,4,4,1,0,3,0,0],
        [0,3,0,0,1,1,1,1,0,0,3,0],
        [0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    private static let shakePixels: [(Int, Int, Color)] = {
        let outline = Color(red: 0.30, green: 0.30, blue: 0.32)
        let screen  = Color(red: 0.55, green: 0.62, blue: 0.72)
        let motion  = Color(red: 0.90, green: 0.70, blue: 0.25)
        let button  = Color(red: 0.42, green: 0.42, blue: 0.45)

        return build(shakeShape) {
            switch $0 {
            case 1: return outline
            case 2: return screen
            case 3: return motion
            case 4: return button
            default: return nil
            }
        }
    }()

    // MARK: - Language globe

    /// 12x12 globe with latitude/longitude grid lines.
    /// 0=transparent  1=outline/grid  2=ocean  3=highlight
    private static let languageShape: [[Int]] = [
        [0,0,0,0,1,1,1,1,0,0,0,0],
        [0,0,1,1,3,1,1,2,1,1,0,0],
        [0,1,3,1,3,2,2,2,1,2,1,0],
        [0,1,3,2,2,2,2,2,2,2,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,1,0],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,1,2,2,2,2,1,2,1,0],
        [0,0,1,1,2,1,1,2,1,1,0,0],
        [0,0,0,0,1,1,1,1,0,0,0,0],
    ]

    private static let languagePixels: [(Int, Int, Color)] = {
        let outline = Color(red: 0.15, green: 0.25, blue: 0.40)
        let ocean   = Color(red: 0.35, green: 0.55, blue: 0.80)
        let hi      = Color(red: 0.55, green: 0.75, blue: 0.95)

        return build(languageShape) {
            switch $0 {
            case 1: return outline
            case 2: return ocean
            case 3: return hi
            default: return nil
            }
        }
    }()

    // MARK: - Helper

    private static func build(
        _ shape: [[Int]],
        color: (Int) -> Color?
    ) -> [(Int, Int, Color)] {
        var out: [(Int, Int, Color)] = []
        for (row, line) in shape.enumerated() {
            for (col, cell) in line.enumerated() {
                if let c = color(cell) {
                    out.append((col, row, c))
                }
            }
        }
        return out
    }
}
