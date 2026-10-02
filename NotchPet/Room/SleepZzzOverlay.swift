import SwiftUI

/// Floating pixel-art "Zzz" above the pet's head while `petState.isAsleep`.
/// Three Z glyphs of increasing size stacked diagonally, drawn pixel-by-
/// pixel so the sleep cue matches the procedural aesthetic of the pet
/// sprite and status icons. Grows + rises + fades on a 2s loop that
/// matches the sprite's breathing cycle.
///
/// Position is owned by the caller: place this view inside the same
/// GeometryReader that positions the pet, anchored above the sprite.
struct SleepZzzOverlay: View {
    /// Loop duration in seconds. Matches the sprite's 2s breathing cycle
    /// so body + Zzz feel unified.
    private static let period: Double = 2.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: false)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.period) / Self.period
            // Scale grows 0.55 → 1.35, opacity fades 0 → 0.95 → 0, drifts up.
            let scale  = 0.55 + CGFloat(t) * 0.80
            let rise   = CGFloat(t) * 18
            // Bell-shaped alpha so the Zzz fades in at start and out at end.
            let alpha  = Double(sin(.pi * t)) * 0.95

            PixelZzzGlyph()
                .frame(width: 26, height: 26)
                .opacity(alpha)
                .scaleEffect(scale, anchor: .bottomLeading)
                .offset(y: -rise)
        }
        .allowsHitTesting(false)
    }
}

/// Three diagonally-stacked "Z" glyphs rendered on a 13×13 pixel grid.
/// Small Z sits top-right, medium in the middle, large at bottom-left —
/// classic Tamagotchi sleep bubble shape.
private struct PixelZzzGlyph: View {
    private static let tint = Color(red: 0.92, green: 0.95, blue: 1.0)
    private static let shadowTint = Color.black.opacity(0.45)
    private static let gridSide: Int = 13
    private static let cells: [(Int, Int)] = buildCells()

    private static func buildCells() -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        // Large Z (5×5) anchored bottom-left.
        result += zCells(originX: 0, originY: 8, size: 5)
        // Medium Z (4×4) middle, offset up-right.
        result += zCells(originX: 5, originY: 4, size: 4)
        // Small Z (3×3) top-right.
        result += zCells(originX: 9, originY: 1, size: 3)
        return result
    }

    /// Build cells for one Z glyph of side `size` at (originX, originY).
    /// Z = top row + diagonal (top-right → bottom-left) + bottom row.
    private static func zCells(originX: Int, originY: Int, size: Int) -> [(Int, Int)] {
        var cells: [(Int, Int)] = []
        // Top bar.
        for c in 0..<size { cells.append((originX + c, originY)) }
        // Diagonal, excluding endpoints (already covered by bars).
        for i in 1..<(size - 1) {
            let col = size - 1 - i
            cells.append((originX + col, originY + i))
        }
        // Bottom bar.
        for c in 0..<size { cells.append((originX + c, originY + size - 1)) }
        return cells
    }

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let pixel = side / CGFloat(Self.gridSide)
            let ox = (canvasSize.width - pixel * CGFloat(Self.gridSide)) / 2
            let oy = (canvasSize.height - pixel * CGFloat(Self.gridSide)) / 2

            // Drop-shadow pass: offset 1 pixel down+right so the glyph
            // stays legible against light room themes.
            for (x, y) in Self.cells {
                let rect = CGRect(
                    x: ox + CGFloat(x) * pixel + pixel,
                    y: oy + CGFloat(y) * pixel + pixel,
                    width: pixel, height: pixel
                )
                gc.fill(Path(rect), with: .color(Self.shadowTint))
            }
            // Foreground pass.
            for (x, y) in Self.cells {
                let rect = CGRect(
                    x: ox + CGFloat(x) * pixel,
                    y: oy + CGFloat(y) * pixel,
                    width: pixel, height: pixel
                )
                gc.fill(Path(rect), with: .color(Self.tint))
            }
        }
        .drawingGroup()
    }
}
