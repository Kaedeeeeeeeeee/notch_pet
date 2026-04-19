import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Memorial card shown after the farewell animation instead of the old
/// `RebornConfirmOverlay`. Shows a pixel-art summary of the deceased
/// pet's life (name, species, personality, days lived, feed/play counts,
/// weight, generation) and offers two actions: export the card as a PNG
/// or accept the new egg. The image that gets exported excludes both
/// buttons and the scrim — just the card content.
struct MemorialCardOverlay: View {
    @ObservedObject var petState: PetState
    private var lang: AppLanguage { AppSettings.shared.language }

    private static let cardWidth: CGFloat = 260
    private static let bgColor    = Color(red: 0.96, green: 0.92, blue: 0.84)
    private static let frameColor = Color(red: 0.42, green: 0.28, blue: 0.15)

    var body: some View {
        ZStack {
            Color.black.opacity(0.70).ignoresSafeArea()

            // Nudge down so the card doesn't clip under the physical
            // notch cutout at the top of the panel.
            VStack {
                Spacer().frame(height: 52)
                cardBody(includeButtons: true)
                    .frame(width: Self.cardWidth)
                    .padding(14)
                    .background(cardBackground)
                Spacer()
            }
        }
        .onTapGesture { } // swallow background taps
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Self.bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Self.frameColor, lineWidth: 2)
            )
    }

    // MARK: - Card content (shared between on-screen + exported image)

    @ViewBuilder
    private func cardBody(includeButtons: Bool) -> some View {
        VStack(spacing: 8) {
            // Title
            Text(lang.memorialTitle)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Self.frameColor)

            Rectangle()
                .fill(Self.frameColor.opacity(0.5))
                .frame(width: 80, height: 1)

            // Pet sprite hero.
            SpriteImage(
                species: petState.species,
                stage: heroStage,
                mode: .idle,
                personality: petState.personality
            )
            .frame(width: 54, height: 54)

            // Name
            Text(petState.name)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(Self.frameColor)

            // Personality · Gen
            Text(personalityAndGen)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Self.frameColor.opacity(0.75))

            // Lifespan headline
            Text(lang.memorialLivedDays(days: livedDays))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Self.frameColor)
                .padding(.top, 2)

            // Born → departed dates
            Text(lifespanDates)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Self.frameColor.opacity(0.6))

            // Stats grid (2x2)
            statsGrid

            // Lineage — shown only if this pet has known parents (bred).
            if let parents = petState.parents, parents.count >= 2 {
                Text("\(lang.memorialParentsLabel)  \(shortID(parents[0])) × \(shortID(parents[1]))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Self.frameColor.opacity(0.6))
                    .padding(.top, 2)
            }

            if includeButtons {
                HStack(spacing: 8) {
                    cardButton(lang.memorialSaveImage) { saveAsImage() }
                    cardButton(lang.departRebornButton) { petState.confirmReborn() }
                }
                .padding(.top, 2)
            }
        }
    }

    private var statsGrid: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                statCell(label: lang.memorialFedLabel,
                         value: "\(petState.careHistory.feedCount)")
                statCell(label: lang.memorialPlayedLabel,
                         value: "\(petState.careHistory.playCount)")
            }
            HStack(spacing: 6) {
                statCell(label: lang.memorialWeightLabel,
                         value: "\(petState.weight)\(lang.memorialWeightUnit)")
                statCell(label: lang.memorialGenerationLabel,
                         value: "\(petState.generation)")
            }
        }
        .padding(.horizontal, 2)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Self.frameColor.opacity(0.7))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Self.frameColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Self.frameColor.opacity(0.08))
        )
    }

    private func cardButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Self.frameColor)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived labels

    private var heroStage: LifecycleStage {
        // If the pet died as an egg/child it never reached the adult
        // sprite — fall back to whatever stage it actually lived as.
        switch petState.stage {
        case .departed:
            // We've already been flipped to .departed by triggerDeath.
            // Use adult for the sprite so there's a recognisable hero,
            // unless personality is nil (died pre-adult) — then child.
            return petState.personality == nil ? .child : .adult
        default:
            return petState.stage
        }
    }

    private var personalityAndGen: String {
        let personalityName = petState.personality?.displayName ?? "—"
        return "\(personalityName) · \(lang.memorialGenerationLabel) \(petState.generation)"
    }

    private var livedDays: Int {
        max(0, Int(petState.ageDays.rounded()))
    }

    /// 8-char prefix of a UUID, used for compact lineage display.
    private func shortID(_ uuid: UUID) -> String {
        String(uuid.uuidString.prefix(8))
    }

    private var lifespanDates: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let born = df.string(from: petState.bornAt)
        let ended = df.string(from: petState.departedAt ?? Date())
        return "\(born) → \(ended)"
    }

    // MARK: - Image export

    @MainActor
    private func saveAsImage() {
        let exportView = cardBody(includeButtons: false)
            .frame(width: Self.cardWidth)
            .padding(20)
            .background(cardBackground)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0

        guard
            let nsImage = renderer.nsImage,
            let tiff   = nsImage.tiffRepresentation,
            let rep    = NSBitmapImageRep(data: tiff),
            let png    = rep.representation(using: .png, properties: [:])
        else { return }

        // Non-activating panel won't become key automatically; without
        // this the save dialog can appear behind the notch panel.
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(petState.name)_memorial.png"
        panel.title = lang.memorialSaveImage

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? png.write(to: url)
        }
    }
}
