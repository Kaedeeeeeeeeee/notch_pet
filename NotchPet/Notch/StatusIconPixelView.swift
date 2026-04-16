import SwiftUI

/// Flat single-color pixel sprites for the right-side status indicator on
/// the collapsed notch strip. Replaces the original emoji icons so the
/// notch matches the procedural pixel art used by `PetView` and
/// `ActionIconView`. Each sprite is a 16x16 grid; cells set to 1 are filled
/// with the kind's tint, every other cell is transparent (the notch
/// background bleeds through).
struct StatusIconPixelView: View {
    let kind: Kind
    let size: CGFloat

    enum Kind {
        case hungry
        case lowMood   // now "happy at 0" (renamed from low-energy)
        case sleeping
        case departed
        case sick
        case poop      // Block 6: at least one poop on the floor
    }

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let pixel = side / CGFloat(Self.gridSide)
            let ox = (canvasSize.width - pixel * CGFloat(Self.gridSide)) / 2
            let oy = (canvasSize.height - pixel * CGFloat(Self.gridSide)) / 2
            let tint = Self.color(for: kind)

            for (x, y) in Self.cells(for: kind) {
                let rect = CGRect(
                    x: ox + CGFloat(x) * pixel,
                    y: oy + CGFloat(y) * pixel,
                    width: pixel,
                    height: pixel
                )
                gc.fill(Path(rect), with: .color(tint))
            }
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }

    // MARK: - Palette

    /// Muted, low-saturation tints. Pure black notch background means very
    /// dim colors still read; saturated yellows / reds would feel garish.
    private static func color(for kind: Kind) -> Color {
        switch kind {
        case .hungry:    return Color(red: 0.80, green: 0.66, blue: 0.42)
        case .lowMood:   return Color(red: 0.78, green: 0.50, blue: 0.55)
        case .sleeping:  return Color(red: 0.62, green: 0.72, blue: 0.84)
        case .departed:  return Color(red: 0.74, green: 0.70, blue: 0.62)
        case .sick:      return Color(red: 0.82, green: 0.52, blue: 0.72)
        case .poop:      return Color(red: 0.55, green: 0.35, blue: 0.20)
        }
    }

    // MARK: - Shapes

    private static let gridSide: Int = 16

    private static func cells(for kind: Kind) -> [(Int, Int)] {
        switch kind {
        case .hungry:    return hungryCells
        case .lowMood:   return brokenHeartCells
        case .sleeping:  return zCells
        case .departed:  return ghostCells
        case .sick:      return sickCells
        case .poop:      return poopCells
        }
    }

    /// Walks a 16x16 cell grid and emits (col, row) pairs for every `1`.
    private static func unpack(_ shape: [[Int]]) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        for (row, line) in shape.enumerated() {
            for (col, cell) in line.enumerated() where cell == 1 {
                out.append((col, row))
            }
        }
        return out
    }

    /// Bowl: thin rim above a trapezoid body. Reads as a rice bowl without
    /// needing to render any rice — the gap row between rim and body is the
    /// silhouette.
    private static let hungryCells: [(Int, Int)] = unpack([
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ])

    /// Lightning bolt: top diagonal stroke, horizontal kink in the middle,
    /// bottom diagonal continuing past the kink.
    private static let lightningCells: [(Int, Int)] = unpack([
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ])

    /// Broken heart: two mirrored half-hearts split by a single transparent
    /// column. The bottom point is also split into two distinct tips so the
    /// "broken" reading survives at small sizes.
    private static let brokenHeartCells: [(Int, Int)] = unpack([
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0],
        [0,0,0,1,1,1,1,1,0,1,1,1,1,1,0,0],
        [0,0,1,1,1,1,1,1,0,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,1,1,0,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,1,1,0,1,1,1,1,1,1,0],
        [0,0,0,1,1,1,1,1,0,1,1,1,1,1,0,0],
        [0,0,0,0,1,1,1,1,0,1,1,1,1,0,0,0],
        [0,0,0,0,0,1,1,1,0,1,1,1,0,0,0,0],
        [0,0,0,0,0,0,1,1,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ])

    /// Capital Z. Two-pixel-thick top bar, diagonal connector, two-pixel
    /// bottom bar.
    private static let zCells: [(Int, Int)] = unpack([
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ])

    /// Small stylised poop pile: three stacked soft-serve swirls.
    private static let poopCells: [(Int, Int)] = unpack([
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
        [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ])

    /// Skull icon: universally reads as "danger / sick". Rounded dome
    /// with two eye holes and a row of teeth at the bottom.
    private static let sickCells: [(Int, Int)] = unpack([
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,0,1,0,0,1,1,1,0,0,1,1,0,0,0],
        [0,0,0,1,0,0,1,1,1,0,0,1,1,0,0,0],
        [0,0,0,1,1,1,1,0,1,1,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,1,0,1,0,1,0,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ])

    /// Tiny ghost. Rounded dome, two transparent eye dots, classic
    /// alternating wavy bottom (5 single-pixel lobes).
    private static let ghostCells: [(Int, Int)] = unpack([
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,0,1,1,1,0,1,1,0,0,0,0],
        [0,0,0,1,1,0,1,1,1,0,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,0,1,0,1,0,1,0,1,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ])
}
