import SwiftUI

/// A room theme is a pure SwiftUI background view — no sprites, no
/// assets. Block 6 ships 4: the default (free), and 3 unlockable.
struct RoomThemeDefinition: Identifiable, Hashable {
    let id: String
    let displayName: String
    let price: Int

    /// Built-in catalog. Stable order: default first, then unlockables
    /// in alphabetical order by id. Purchase prices chosen so the first
    /// unlock is reachable after ~1 full care loop (~30 coins).
    static let all: [RoomThemeDefinition] = [
        RoomThemeDefinition(id: "default",  displayName: "标准", price: 0),
        RoomThemeDefinition(id: "washitsu", displayName: "和风", price: 80),
        RoomThemeDefinition(id: "space",    displayName: "太空", price: 120),
        RoomThemeDefinition(id: "forest",   displayName: "森林", price: 80),
    ]

    static func find(_ id: String) -> RoomThemeDefinition {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

/// SwiftUI background view factory for a given theme id.
struct RoomThemeBackground: View {
    let themeID: String

    var body: some View {
        switch themeID {
        case "washitsu": WashitsuBackground()
        case "space":    SpaceBackground()
        case "forest":   ForestBackground()
        default:         DefaultBackground()
        }
    }
}

// MARK: - Default
//
// Cream-white plaster wall, warm wooden floor with plank seams, thin
// darker baseboard at the wall/floor seam, and a small pixel-art 4-pane
// window set high on the wall offset to the left so it doesn't clash
// with the wall-back furniture slot.

private struct DefaultBackground: View {
    var body: some View {
        GeometryReader { geo in
            let floorHeight = geo.size.height * 0.26
            ZStack {
                // Base wall — cream plaster
                Color(red: 0.94, green: 0.90, blue: 0.82)

                // Wooden floor strip (bottom)
                VStack(spacing: 0) {
                    Spacer()
                    WoodFloor()
                        .frame(height: floorHeight)
                }

                // Baseboard — a thin darker wood stripe right where
                // the wall meets the floor.
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(Color(red: 0.42, green: 0.28, blue: 0.15))
                        .frame(height: 2)
                    Spacer().frame(height: floorHeight)
                }

                // Small window, upper-left of the wall. Positioned so
                // the wall-back furniture slot (centered) remains free.
                WindowPixel()
                    .frame(width: 78, height: 56)
                    .shadow(color: Color.black.opacity(0.25), radius: 3, y: 2)
                    .position(
                        x: geo.size.width * 0.28,
                        y: geo.size.height * 0.20
                    )
            }
        }
    }
}

/// Repeating-plank wood floor.
private struct WoodFloor: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.56, green: 0.38, blue: 0.22)
            // Subtle plank highlight band along the top edge so the
            // floor reads as receding slightly.
            LinearGradient(
                colors: [
                    Color(red: 0.70, green: 0.50, blue: 0.30).opacity(0.35),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)
            // Horizontal plank seams every 14pt.
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { i in
                    Spacer().frame(height: 14)
                    Rectangle()
                        .fill(Color(red: 0.32, green: 0.20, blue: 0.10).opacity(0.75))
                        .frame(height: 1)
                    if i == 7 { Spacer().frame(height: 14) }
                }
            }
        }
    }
}

/// Pixel-art 4-pane window with a wooden frame and a pale-blue sky
/// peeking through. 18×12 logical pixels; scales nearest-neighbor via
/// the Canvas renderer so edges stay crisp at any display size.
private struct WindowPixel: View {
    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, size in
            let gridW = 18
            let gridH = 12
            let px = min(size.width / CGFloat(gridW), size.height / CGFloat(gridH))
            let ox = (size.width - px * CGFloat(gridW)) / 2
            let oy = (size.height - px * CGFloat(gridH)) / 2

            let frame   = Color(red: 0.48, green: 0.32, blue: 0.18)
            let frameHi = Color(red: 0.65, green: 0.45, blue: 0.25)
            let sky     = Color(red: 0.68, green: 0.84, blue: 0.98)
            let skyHi   = Color(red: 0.86, green: 0.93, blue: 1.00)
            let cloud   = Color(red: 1.00, green: 1.00, blue: 1.00)
            let sill    = Color(red: 0.38, green: 0.24, blue: 0.12)

            for (row, line) in Self.grid.enumerated() {
                for (col, cell) in line.enumerated() {
                    let color: Color
                    switch cell {
                    case 1: color = frame
                    case 2: color = sky
                    case 3: color = cloud
                    case 4: color = sill
                    case 5: color = frameHi
                    case 6: color = skyHi
                    default: continue
                    }
                    let rect = CGRect(
                        x: ox + CGFloat(col) * px,
                        y: oy + CGFloat(row) * px,
                        width: px,
                        height: px
                    )
                    gc.fill(Path(rect), with: .color(color))
                }
            }
        }
    }

    /// 18×12 grid. Cells:
    /// 0 = transparent
    /// 1 = frame (wood)
    /// 2 = sky (light blue)
    /// 3 = cloud (white)
    /// 4 = sill (dark wood, bottom row)
    /// 5 = frame highlight
    /// 6 = sky highlight (upper band inside each pane)
    private static let grid: [[Int]] = [
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [1,5,5,5,5,5,5,5,1,5,5,5,5,5,5,5,5,1],
        [1,5,6,6,6,6,6,5,1,5,6,6,6,6,6,6,5,1],
        [1,5,2,2,3,2,2,5,1,5,2,2,2,2,2,2,5,1],
        [1,5,2,3,3,3,2,5,1,5,2,2,2,2,2,2,5,1],
        [1,5,2,2,2,2,2,5,1,5,2,2,2,2,2,2,5,1],
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [1,5,2,2,2,2,2,5,1,5,2,2,2,3,3,2,5,1],
        [1,5,2,2,2,2,2,5,1,5,2,2,3,3,3,2,5,1],
        [1,5,2,2,2,2,2,5,1,5,2,2,2,2,2,2,5,1],
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4],
    ]
}

// MARK: - Washitsu (Japanese room)
//
// Traditional Japanese interior: warm sand-coloured plaster wall, a
// pixel-art shoji (paper sliding panel) on the left wall, and a
// tatami floor with the distinctive straw-green colour + dark seam
// borders.

private struct WashitsuBackground: View {
    var body: some View {
        GeometryReader { geo in
            let floorHeight = geo.size.height * 0.28
            ZStack {
                // Sand plaster wall
                Color(red: 0.92, green: 0.86, blue: 0.74)

                // Tatami floor
                VStack(spacing: 0) {
                    Spacer()
                    TatamiFloor()
                        .frame(height: floorHeight)
                }

                // Dark wood baseboard
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(Color(red: 0.30, green: 0.20, blue: 0.12))
                        .frame(height: 2)
                    Spacer().frame(height: floorHeight)
                }

                // Shoji panel on the right wall
                ShojiPixel()
                    .frame(width: 80, height: 90)
                    .position(
                        x: geo.size.width * 0.78,
                        y: geo.size.height * 0.32
                    )

                // Small hanging scroll (kakejiku) on the left wall
                KakejikuPixel()
                    .frame(width: 30, height: 54)
                    .position(
                        x: geo.size.width * 0.22,
                        y: geo.size.height * 0.28
                    )
            }
        }
    }
}

/// Tatami floor: straw-green with horizontal and vertical dark seam
/// lines forming the characteristic rectangular mat layout.
private struct TatamiFloor: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Base straw green
            Color(red: 0.62, green: 0.58, blue: 0.38)
            // Subtle woven texture via thin horizontal lines
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { _ in
                    Spacer().frame(height: 10)
                    Rectangle()
                        .fill(Color(red: 0.55, green: 0.50, blue: 0.30).opacity(0.5))
                        .frame(height: 1)
                }
            }
            // Dark edge borders (tatami-beri) — one horizontal mid-line
            // and two vertical dividers
            GeometryReader { geo in
                // Horizontal mid-line
                Rectangle()
                    .fill(Color(red: 0.22, green: 0.18, blue: 0.10))
                    .frame(width: geo.size.width, height: 2)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                // Left vertical divider
                Rectangle()
                    .fill(Color(red: 0.22, green: 0.18, blue: 0.10))
                    .frame(width: 2, height: geo.size.height)
                    .position(x: geo.size.width * 0.33, y: geo.size.height / 2)
                // Right vertical divider
                Rectangle()
                    .fill(Color(red: 0.22, green: 0.18, blue: 0.10))
                    .frame(width: 2, height: geo.size.height)
                    .position(x: geo.size.width * 0.67, y: geo.size.height / 2)
            }
        }
    }
}

/// Shoji (paper sliding panel): white washi paper panes inside a
/// wooden lattice frame. 20×22 pixel grid.
private struct ShojiPixel: View {
    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, size in
            let gridW = 20
            let gridH = 22
            let px = min(size.width / CGFloat(gridW), size.height / CGFloat(gridH))
            let ox = (size.width - px * CGFloat(gridW)) / 2
            let oy = (size.height - px * CGFloat(gridH)) / 2
            let frame_ = Color(red: 0.45, green: 0.30, blue: 0.15)
            let paper  = Color(red: 0.96, green: 0.94, blue: 0.88)
            let paperHi = Color(red: 1.00, green: 0.98, blue: 0.95)
            for (row, line) in Self.grid.enumerated() {
                for (col, cell) in line.enumerated() {
                    let c: Color
                    switch cell {
                    case 1: c = frame_
                    case 2: c = paper
                    case 3: c = paperHi
                    default: continue
                    }
                    gc.fill(
                        Path(CGRect(
                            x: ox + CGFloat(col) * px,
                            y: oy + CGFloat(row) * px,
                            width: px, height: px)),
                        with: .color(c))
                }
            }
        }
    }
    // 20×22 shoji: wooden frame + 2×3 washi paper panes
    private static let grid: [[Int]] = [
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [1,2,3,2,2,2,2,2,2,1,2,2,2,2,2,2,3,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,3,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
        [1,2,2,2,2,3,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,3,2,1],
        [1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,2,1],
        [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    ]
}

/// Kakejiku (hanging wall scroll): a narrow vertical scroll with a
/// simple ink-wash circle (ensō) motif. 10×18 pixel grid.
private struct KakejikuPixel: View {
    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, size in
            let gridW = 10
            let gridH = 18
            let px = min(size.width / CGFloat(gridW), size.height / CGFloat(gridH))
            let ox = (size.width - px * CGFloat(gridW)) / 2
            let oy = (size.height - px * CGFloat(gridH)) / 2
            let cord   = Color(red: 0.30, green: 0.20, blue: 0.10)
            let mount  = Color(red: 0.60, green: 0.48, blue: 0.32)
            let paper  = Color(red: 0.95, green: 0.92, blue: 0.85)
            let ink    = Color(red: 0.15, green: 0.15, blue: 0.12)
            let roller = Color(red: 0.35, green: 0.22, blue: 0.12)
            for (row, line) in Self.grid.enumerated() {
                for (col, cell) in line.enumerated() {
                    let c: Color
                    switch cell {
                    case 1: c = cord
                    case 2: c = mount
                    case 3: c = paper
                    case 4: c = ink
                    case 5: c = roller
                    default: continue
                    }
                    gc.fill(
                        Path(CGRect(
                            x: ox + CGFloat(col) * px,
                            y: oy + CGFloat(row) * px,
                            width: px, height: px)),
                        with: .color(c))
                }
            }
        }
    }
    // 10×18 kakejiku: cord, mounting, paper with ensō, bottom roller
    private static let grid: [[Int]] = [
        [0,0,0,0,1,1,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,0],
        [0,2,2,2,2,2,2,2,2,0],
        [0,2,3,3,3,3,3,3,2,0],
        [0,2,3,3,3,3,3,3,2,0],
        [0,2,3,3,4,4,3,3,2,0],
        [0,2,3,4,3,3,4,3,2,0],
        [0,2,3,4,3,3,4,3,2,0],
        [0,2,3,4,3,3,4,3,2,0],
        [0,2,3,3,4,4,3,3,2,0],
        [0,2,3,3,3,3,3,3,2,0],
        [0,2,3,3,3,3,3,3,2,0],
        [0,2,3,3,3,4,3,3,2,0],
        [0,2,3,3,4,4,3,3,2,0],
        [0,2,3,3,3,3,3,3,2,0],
        [0,2,2,2,2,2,2,2,2,0],
        [5,5,5,5,5,5,5,5,5,5],
        [0,0,0,0,0,0,0,0,0,0],
    ]
}

// MARK: - Space (galaxy starfield)
//
// Pixel-art deep space rendered as a single Canvas on a 135×100 grid
// (~4 pt per cell). Dithered nebula clouds, scattered pixel stars,
// a ringed planet, and a shooting star trail.

private struct SpaceBackground: View {
    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, size in
            let gw = Self.gW, gh = Self.gH
            let pxW = size.width / CGFloat(gw)
            let pxH = size.height / CGFloat(gh)

            for row in 0..<gh {
                for col in 0..<gw {
                    let cell = Self.grid[row][col]
                    let color: Color
                    if cell == 0 {
                        // Dark space gradient with banding (discrete steps)
                        let band = Double(row / 10) / Double(gh / 10)
                        color = Color(
                            red:   0.02 + 0.04 * band,
                            green: 0.01 + 0.02 * band,
                            blue:  0.08 + 0.10 * band
                        )
                    } else {
                        guard let c = Self.pal[cell] else { continue }
                        color = c
                    }
                    gc.fill(
                        Path(CGRect(x: CGFloat(col) * pxW, y: CGFloat(row) * pxH,
                                    width: ceil(pxW), height: ceil(pxH))),
                        with: .color(color))
                }
            }
        }
    }

    // Grid dimensions (each cell ≈ 4 pt at 540×400)
    private static let gW = 135
    private static let gH = 100

    // Palette — 0 is background (handled inline), rest map to colors.
    // 1/2 = nebula purple, 3 = nebula pink, 4 = nebula teal,
    // 5 = dim star, 6 = bright star, 7 = blue star, 8 = warm star,
    // 9/10 = planet body, 11 = planet ring, 12 = shooting star
    private static let pal: [UInt8: Color] = [
        1:  Color(red: 0.18, green: 0.08, blue: 0.30),
        2:  Color(red: 0.30, green: 0.15, blue: 0.45),
        3:  Color(red: 0.45, green: 0.18, blue: 0.35),
        4:  Color(red: 0.15, green: 0.30, blue: 0.45),
        5:  Color(red: 0.60, green: 0.60, blue: 0.65),
        6:  Color(red: 0.95, green: 0.95, blue: 1.00),
        7:  Color(red: 0.55, green: 0.70, blue: 1.00),
        8:  Color(red: 1.00, green: 0.80, blue: 0.55),
        9:  Color(red: 0.55, green: 0.40, blue: 0.85),
        10: Color(red: 0.28, green: 0.16, blue: 0.52),
        11: Color(red: 0.65, green: 0.55, blue: 0.85),
        12: Color(red: 0.85, green: 0.85, blue: 0.95),
    ]

    // ---- Planet template (16×14, ring wraps around body) ----
    private static let planet: [[UInt8]] = [
        [ 0, 0,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [ 0, 0, 0,11, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [ 0, 0, 0, 0,11, 9, 9, 9, 9, 0, 0, 0, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 0, 9, 9, 9, 9, 9,10, 0, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 9, 9, 9, 9,10,10,10,10, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 9, 9, 9,10,10,10,10,10, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 9, 9, 9,10,10,10,10,10, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 9, 9, 9,10,10,10,10,10, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 9, 9, 9, 9,10,10,10,10, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 0, 9, 9, 9, 9,10,10, 0, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 0, 0, 9, 9, 9, 9, 0,11, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11, 0, 0, 0],
        [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,11, 0, 0],
        [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ]

    // ---- Scene builder ----

    private static func stamp(
        _ g: inout [[UInt8]], _ t: [[UInt8]], cx: Int, baseRow: Int
    ) {
        let tH = t.count, tW = t[0].count
        let sr = baseRow - tH + 1, sc = cx - tW / 2
        for tr in 0..<tH {
            for tc in 0..<tW {
                let v = t[tr][tc]
                if v == 0 { continue }
                let r = sr + tr, c = sc + tc
                if r >= 0, r < gH, c >= 0, c < gW { g[r][c] = v }
            }
        }
    }

    private static let grid: [[UInt8]] = {
        var g = Array(repeating: Array(repeating: UInt8(0), count: gW), count: gH)

        // --- 1. Nebula clouds (dithered scatter) ---

        // Main diagonal purple nebula band (upper-left to lower-right)
        for r in 15..<75 {
            for c in 12..<125 {
                let centerR = 15 + (c - 12) * 53 / 113
                let dist = abs(r - centerR)
                let hash = (r &* 7 &+ c &* 13 &+ r &* c &* 3) % 31
                if dist < 8 && hash < 7 {
                    g[r][c] = 2   // mid purple (dense core)
                } else if dist < 14 && hash < 3 {
                    g[r][c] = 1   // dark purple (sparse edge)
                }
            }
        }

        // Warm pink nebula accent (right side)
        for r in 45..<75 {
            for c in 75..<125 {
                let dist = abs(c - 98) + abs(r - 58)
                let hash = (r &* 11 &+ c &* 7) % 23
                if dist < 12 && hash < 5 {
                    g[r][c] = 3   // warm pink
                } else if dist < 18 && hash < 2 {
                    g[r][c] = 1   // dark purple fringe
                }
            }
        }

        // Small teal nebula patch (lower left)
        for r in 62..<85 {
            for c in 10..<45 {
                let dist = abs(c - 27) + abs(r - 72)
                let hash = (r &* 5 &+ c &* 11) % 17
                if dist < 10 && hash < 5 {
                    g[r][c] = 4   // teal
                } else if dist < 15 && hash < 2 {
                    g[r][c] = 1   // dark purple
                }
            }
        }

        // --- 2. Stars ---

        // Bright stars with cross-sparkle pattern (+)
        let sparkles: [(Int, Int, UInt8)] = [
            ( 12, 15, 7),   // blue (upper left)
            ( 67, 40, 6),   // white (center)
            (122, 12, 8),   // warm (upper right)
            ( 35, 82, 7),   // blue (lower left)
            ( 95, 22, 6),   // white (mid-upper right)
        ]
        for (c, r, v) in sparkles {
            g[r][c] = v
            if r > 0     { g[r-1][c] = 5 }
            if r < gH-1  { g[r+1][c] = 5 }
            if c > 0     { g[r][c-1] = 5 }
            if c < gW-1  { g[r][c+1] = 5 }
        }

        // 2×2 bright star clusters (small but visible star bodies)
        let clusters: [(Int, Int, UInt8)] = [
            ( 55, 28, 6),   // white
            ( 85, 65, 7),   // blue
            ( 15, 72, 8),   // warm
        ]
        for (c, r, v) in clusters {
            g[r][c] = v;     g[r][c+1] = v
            g[r+1][c] = v;   g[r+1][c+1] = v
        }

        // Medium stars (single bright pixel)
        let medStars: [(Int, Int, UInt8)] = [
            ( 40, 30, 6),  ( 95, 55, 7),  ( 60, 10, 7),  ( 20, 50, 8),
            ( 80, 77, 6),  (115, 42, 7),  ( 50, 62, 6),  (105, 87, 8),
            (  8, 90, 7),  ( 75, 15, 6),  ( 28, 35, 8),  (130, 65, 7),
        ]
        for (c, r, v) in medStars { g[r][c] = v }

        // Dim stars (scattered single pixels)
        let dimStars: [(Int, Int)] = [
            ( 30,  5), ( 82,  5), (117, 20), (  7, 27),
            ( 68, 22), (  7, 70), (125, 65), ( 55, 87),
            (100,  7), ( 25, 95), (128, 92), ( 75, 47),
            ( 45, 37), ( 88, 70), (112, 80), ( 17, 87),
            ( 62, 95), (130, 35), (  3, 45), ( 92, 25),
            ( 15, 12), ( 48,  3), (110, 50), ( 38, 72),
            ( 72, 60), (  5, 60), (120, 10), ( 58, 45),
            ( 85, 92), ( 22, 18), (102, 32), ( 43, 85),
            (133, 48), ( 10, 35), ( 65, 78), (118, 58),
            ( 52, 20), ( 90, 88), ( 33, 55), (108, 15),
        ]
        for (c, r) in dimStars { g[r][c] = 5 }

        // --- 3. Planet (upper right) ---
        stamp(&g, planet, cx: 110, baseRow: 28)

        // --- 4. Shooting star (diagonal trail, upper left) ---
        g[ 7][28] = 5     // dim tail
        g[ 8][29] = 5
        g[ 9][30] = 5
        g[10][31] = 12    // mid-bright
        g[11][32] = 12
        g[12][33] = 12
        g[13][34] = 6     // bright head
        g[14][35] = 6

        return g
    }()
}

// MARK: - Forest
//
// Pixel-art forest rendered as a single Canvas on a 54×40 grid.
// Three tree layers (far/mid/near) are stamped from small templates,
// giving the same chunky pixel feel as the pet sprites and icons.

private struct ForestBackground: View {
    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, size in
            let gw = Self.gW, gh = Self.gH
            let pxW = size.width / CGFloat(gw)
            let pxH = size.height / CGFloat(gh)

            for row in 0..<gh {
                for col in 0..<gw {
                    let cell = Self.grid[row][col]
                    let color: Color
                    if cell == 0 {
                        // Sky gradient by row
                        let t = Double(row) / Double(gh)
                        color = Color(
                            red: 0.50 - 0.12 * t,
                            green: 0.75 - 0.12 * t,
                            blue: 0.72 - 0.22 * t
                        )
                    } else {
                        guard let c = Self.pal[cell] else { continue }
                        color = c
                    }
                    gc.fill(
                        Path(CGRect(x: CGFloat(col) * pxW, y: CGFloat(row) * pxH,
                                    width: ceil(pxW), height: ceil(pxH))),
                        with: .color(color))
                }
            }
        }
    }

    // Grid dimensions (each cell ≈ 10 pt at 540×400)
    private static let gW = 54
    private static let gH = 40

    // Palette — 0 is sky (handled inline), rest map to colors.
    // 2/3 = far canopy, 4/5 = mid canopy, 6/7 = near canopy,
    // 8/9/10 = grass, 11 = trunk, 12/13 = flowers
    private static let pal: [UInt8: Color] = [
        2:  Color(red: 0.40, green: 0.62, blue: 0.42),
        3:  Color(red: 0.50, green: 0.72, blue: 0.50),
        4:  Color(red: 0.24, green: 0.52, blue: 0.28),
        5:  Color(red: 0.34, green: 0.62, blue: 0.36),
        6:  Color(red: 0.14, green: 0.40, blue: 0.18),
        7:  Color(red: 0.24, green: 0.50, blue: 0.26),
        8:  Color(red: 0.36, green: 0.58, blue: 0.28),
        9:  Color(red: 0.30, green: 0.50, blue: 0.22),
        10: Color(red: 0.44, green: 0.66, blue: 0.34),
        11: Color(red: 0.32, green: 0.22, blue: 0.12),
        12: Color(red: 1.00, green: 0.85, blue: 0.30),
        13: Color(red: 0.92, green: 0.48, blue: 0.55),
    ]

    // ---- Tree templates ----

    private static let farTree: [[UInt8]] = [
        [0, 0, 2, 0, 0],
        [0, 3, 2, 2, 0],
        [3, 2, 2, 2, 2],
        [0, 3, 2, 2, 0],
        [3, 2, 2, 2, 2],
        [0, 0,11, 0, 0],
        [0, 0,11, 0, 0],
    ]

    private static let midTree: [[UInt8]] = [
        [0, 0, 0, 4, 0, 0, 0],
        [0, 0, 5, 4, 4, 0, 0],
        [0, 5, 4, 4, 4, 4, 0],
        [5, 4, 4, 4, 4, 4, 4],
        [0, 0, 5, 4, 4, 0, 0],
        [0, 5, 4, 4, 4, 4, 0],
        [5, 4, 4, 4, 4, 4, 4],
        [0, 0, 0,11, 0, 0, 0],
        [0, 0, 0,11, 0, 0, 0],
    ]

    private static let nearTree: [[UInt8]] = [
        [0, 0, 0, 0, 6, 0, 0, 0, 0],
        [0, 0, 0, 7, 6, 6, 0, 0, 0],
        [0, 0, 7, 6, 6, 6, 6, 0, 0],
        [0, 7, 6, 6, 6, 6, 6, 6, 0],
        [0, 0, 0, 7, 6, 6, 0, 0, 0],
        [0, 0, 7, 6, 6, 6, 6, 0, 0],
        [0, 7, 6, 6, 6, 6, 6, 6, 0],
        [7, 6, 6, 6, 6, 6, 6, 6, 6],
        [0, 0, 7, 6, 6, 6, 6, 0, 0],
        [0, 7, 6, 6, 6, 6, 6, 6, 0],
        [7, 6, 6, 6, 6, 6, 6, 6, 6],
        [0, 0, 0, 0,11, 0, 0, 0, 0],
        [0, 0, 0, 0,11, 0, 0, 0, 0],
    ]

    // ---- Scene builder ----

    private static func stamp(
        _ g: inout [[UInt8]], _ t: [[UInt8]], cx: Int, baseRow: Int
    ) {
        let tH = t.count, tW = t[0].count
        let sr = baseRow - tH + 1, sc = cx - tW / 2
        for tr in 0..<tH {
            for tc in 0..<tW {
                let v = t[tr][tc]
                if v == 0 { continue }
                let r = sr + tr, c = sc + tc
                if r >= 0, r < gH, c >= 0, c < gW { g[r][c] = v }
            }
        }
    }

    private static let grid: [[UInt8]] = {
        var g = Array(repeating: Array(repeating: UInt8(0), count: gW), count: gH)

        // Ground (bottom 25%)
        let gr = 30
        for r in gr..<gH {
            for c in 0..<gW {
                g[r][c] = r == gr ? 10 : ((r + c) % 2 == 0 ? 8 : 9)
            }
        }

        // Far trees (small, high)
        let farPos: [(Int, Int)] = [
            (3,25),(10,24),(17,26),(24,25),(31,24),(38,26),(45,25),(52,24)
        ]
        for (cx, by) in farPos { stamp(&g, farTree, cx: cx, baseRow: by) }

        // Mid trees
        let midPos: [(Int, Int)] = [
            (1,29),(12,28),(22,30),(32,29),(42,28),(52,30)
        ]
        for (cx, by) in midPos { stamp(&g, midTree, cx: cx, baseRow: by) }

        // Near trees (large, overlap ground)
        let nearPos: [(Int, Int)] = [
            (6,33),(18,34),(30,33),(42,34),(52,33)
        ]
        for (cx, by) in nearPos { stamp(&g, nearTree, cx: cx, baseRow: by) }

        // Flowers on the grass
        let flowers: [(Int, Int, UInt8)] = [
            (9,32,12),(15,34,13),(25,33,12),(35,35,13),(44,32,12),(50,34,13)
        ]
        for (c, r, v) in flowers {
            if r < gH, c < gW { g[r][c] = v }
        }

        return g
    }()
}
