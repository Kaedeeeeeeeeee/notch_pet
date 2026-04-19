import SwiftUI

/// Grid of all departed pets fetched from Supabase. Anonymous users
/// will see an empty state with a prompt to sign in; once they link
/// Apple ID, entries from every device they've used show up here.
struct MemorialBookPanel: View {
    @Binding var isShowing: Bool
    @ObservedObject private var settings = AppSettings.shared

    @State private var pets: [CloudPet] = []
    @State private var loading: Bool = true
    @State private var selected: CloudPet? = nil

    private var lang: AppLanguage { settings.language }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                content
                Spacer()
            }

            // Per-entry detail sheet (mini memorial card)
            if let pet = selected {
                MemorialDetailOverlay(pet: pet) {
                    selected = nil
                }
            }
        }
        .onTapGesture { /* swallow */ }
        .task { await reload() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(lang.memorialBookTitle)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            Button {
                isShowing = false
            } label: {
                Text("×")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView()
                .scaleEffect(0.7)
                .padding(.top, 60)
        } else if pets.isEmpty {
            Text(lang.memorialBookEmpty)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 60)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(pets) { pet in
                        Button { selected = pet } label: {
                            cell(for: pet)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private func cell(for pet: CloudPet) -> some View {
        VStack(spacing: 6) {
            if let species = Species(rawValue: pet.species) {
                SpriteImage(
                    species: species,
                    stage: .adult,
                    mode: .idle,
                    personality: pet.personality.flatMap(PersonalityTrait.init(rawValue:))
                )
                .frame(width: 44, height: 44)
            }
            Text(pet.name)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text("Gen \(pet.generation) · \(livedDays(pet))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func livedDays(_ pet: CloudPet) -> String {
        let days = Int(pet.ageActiveSeconds / 86_400).clamped(min: 0)
        return "\(days)d"
    }

    private func reload() async {
        loading = true
        pets = await CloudSync.shared.fetchDepartedPets()
        loading = false
    }
}

// MARK: - Detail overlay (reuses memorial card aesthetic)

private struct MemorialDetailOverlay: View {
    let pet: CloudPet
    let onClose: () -> Void
    @ObservedObject private var settings = AppSettings.shared
    private var lang: AppLanguage { settings.language }

    private static let bgColor    = Color(red: 0.96, green: 0.92, blue: 0.84)
    private static let frameColor = Color(red: 0.42, green: 0.28, blue: 0.15)

    var body: some View {
        ZStack {
            Color.black.opacity(0.80).ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 10) {
                if let species = Species(rawValue: pet.species) {
                    SpriteImage(
                        species: species,
                        stage: .adult,
                        mode: .idle,
                        personality: pet.personality.flatMap(PersonalityTrait.init(rawValue:))
                    )
                    .frame(width: 60, height: 60)
                }
                Text(pet.name)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Self.frameColor)
                let days = Int((pet.ageActiveSeconds / 86_400).rounded())
                Text(lang.memorialLivedDays(days: days))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Self.frameColor)
                Text(datesLine)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Self.frameColor.opacity(0.6))

                HStack(spacing: 12) {
                    smallStat(lang.memorialFedLabel, "\(pet.feedCount)")
                    smallStat(lang.memorialPlayedLabel, "\(pet.playCount)")
                    smallStat(lang.memorialGenerationLabel, "\(pet.generation)")
                }

                Button { onClose() } label: {
                    Text(lang.confirmClose)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Self.frameColor))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .frame(width: 240)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Self.bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Self.frameColor, lineWidth: 2)
                    )
            )
        }
    }

    private func smallStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(Self.frameColor.opacity(0.7))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Self.frameColor)
        }
    }

    private var datesLine: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let born = df.string(from: pet.bornAt)
        let ended = pet.departedAt.map { df.string(from: $0) } ?? "—"
        return "\(born) → \(ended)"
    }
}

private extension Int {
    func clamped(min: Int) -> Int { Swift.max(self, min) }
}
