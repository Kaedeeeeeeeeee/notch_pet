import SwiftUI

/// Plays once when `petState.awaitingRebornConfirm` flips true, before
/// the memorial card takes over. This overlay is now **just** the
/// darkened scrim + the farewell title — the pet sprite itself fades
/// out in its actual floor position (handled by RoomView's PetView
/// opacity), and the rising halo+wings particles are rendered inside
/// RoomView's GeometryReader so they spawn from the pet's real spot.
/// After ~3.5s calls `onFinish()` so the host view can swap in the
/// memorial card overlay.
struct FarewellOverlay: View {
    @ObservedObject var petState: PetState
    let onFinish: () -> Void

    @State private var scrimOpacity: Double = 0
    @State private var titleOpacity: Double = 0

    private var lang: AppLanguage { AppSettings.shared.language }

    private static let totalDuration: TimeInterval = 3.5

    var body: some View {
        ZStack {
            Color.black.opacity(scrimOpacity)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Text(lang.departFarewellTitle(name: petState.name))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .opacity(titleOpacity)
                    .padding(.bottom, 70)
            }
        }
        .onTapGesture { }
        .task {
            withAnimation(.easeIn(duration: 0.6)) { scrimOpacity = 0.55 }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeIn(duration: 0.8)) { titleOpacity = 1 }
            try? await Task.sleep(
                nanoseconds: UInt64((Self.totalDuration - 1.5) * 1_000_000_000)
            )
            onFinish()
        }
    }
}

// MARK: - Ascension particles (halo + wings rising)

/// Rendered by RoomView inside its GeometryReader at the pet's current
/// position while farewell is playing. Spawns a handful of pixel-art
/// "angel spirit" particles that drift up and fade, selling the
/// ascending-to-heaven beat.
struct AscensionParticleField: View {
    private static let count: Int = 4

    var body: some View {
        ZStack {
            ForEach(0..<Self.count, id: \.self) { i in
                AngelParticle(index: i)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AngelParticle: View {
    let index: Int

    @State private var progress: Double = 0
    @State private var startDelay: Double
    @State private var xOffset: CGFloat
    @State private var riseDistance: CGFloat
    @State private var duration: Double
    @State private var size: CGFloat

    init(index: Int) {
        self.index = index
        _xOffset      = State(initialValue: CGFloat.random(in: -24...24))
        _riseDistance = State(initialValue: CGFloat.random(in: 90...130))
        _duration     = State(initialValue: Double.random(in: 1.6...2.2))
        _size         = State(initialValue: CGFloat.random(in: 14...18))
        _startDelay   = State(initialValue: Double(index) * 0.35)
    }

    var body: some View {
        AngelSprite()
            .frame(width: size, height: size)
            .offset(
                x: xOffset + CGFloat(sin(progress * .pi * 2)) * 4, // slight sway
                y: -riseDistance * CGFloat(progress)
            )
            .opacity(1.0 - progress)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
                    withAnimation(.easeOut(duration: duration)) {
                        progress = 1
                    }
                }
            }
    }
}

/// Tiny pixel-art angel silhouette: a halo ring on top and two wings
/// spreading beneath, centered body. Drawn with a Canvas so it shares
/// the chunky pixel aesthetic of `StatusIconPixelView`.
private struct AngelSprite: View {
    /// 11x11 grid. 1 = halo (white), 2 = wing/body (soft gold).
    private static let cells: [[Int]] = [
        [0,0,0,0,1,1,1,0,0,0,0],  // halo top
        [0,0,0,1,0,0,0,1,0,0,0],  // halo ring
        [0,0,0,0,1,1,1,0,0,0,0],  // halo bottom
        [0,0,0,0,0,0,0,0,0,0,0],  // gap
        [0,0,2,2,0,2,0,2,2,0,0],  // upper wings + head
        [0,2,2,2,2,2,2,2,2,2,0],  // full wingspan
        [0,0,2,0,2,2,2,0,2,0,0],  // lower wings + body
        [0,0,0,0,0,2,0,0,0,0,0],  // tail
        [0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0],
    ]

    private static let gridSide: Int = 11
    private static let haloColor = Color(red: 1.0, green: 0.98, blue: 0.80)
    private static let wingColor = Color(red: 0.95, green: 0.93, blue: 0.80)

    var body: some View {
        Canvas(rendersAsynchronously: false) { gc, size in
            let side  = min(size.width, size.height)
            let pixel = side / CGFloat(Self.gridSide)
            let ox    = (size.width  - pixel * CGFloat(Self.gridSide)) / 2
            let oy    = (size.height - pixel * CGFloat(Self.gridSide)) / 2

            for (row, line) in Self.cells.enumerated() {
                for (col, cell) in line.enumerated() where cell != 0 {
                    let rect = CGRect(
                        x: ox + CGFloat(col) * pixel,
                        y: oy + CGFloat(row) * pixel,
                        width: pixel, height: pixel
                    )
                    let color = (cell == 1) ? Self.haloColor : Self.wingColor
                    gc.fill(Path(rect), with: .color(color))
                }
            }
        }
    }
}

// MARK: - Sprite rendering helper (shared by Memorial / Onboarding)

/// Thin SwiftUI wrapper around `PetSpriteLibrary` for one-off static
/// sprite renders (onboarding egg, memorial card hero). Uses frame
/// index 0 — no animation timeline, just the first frame of the tag.
struct SpriteImage: View {
    let species: Species
    let stage: LifecycleStage
    let mode: PetMode
    let personality: PersonalityTrait?

    var body: some View {
        let cg = PetSpriteLibrary.shared.frame(
            species: species,
            stage: stage,
            mode: mode,
            personality: personality,
            frameIndex: 0
        )
        Image(decorative: cg, scale: 1.0)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
