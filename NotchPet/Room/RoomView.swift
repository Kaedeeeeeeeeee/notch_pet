import SwiftUI

/// Expanded popover content shown when the user clicks the notch strip.
/// Live status bars are bound to `PetState`; action buttons drive the
/// corresponding feed/play/rest mutations. Collapse is handled globally by
/// `NotchPanelController`'s dismiss monitors (click-outside or ESC) so this
/// view has no collapse affordance of its own.
struct RoomView: View {
    @ObservedObject var petState: PetState

    var body: some View {
        ZStack {
            RoomBackground()

            VStack(spacing: 14) {
                headerRow
                Spacer()
                PetView(size: 120, petState: petState)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
                Spacer()
                VitalsStrip(petState: petState)
                    .padding(.horizontal, 20)
                ActionBar(petState: petState)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if petState.isAsleep {
                SleepOverlay()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(petState.name)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    if let trait = petState.personality {
                        Text(trait.displayName)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.white.opacity(0.12))
                            )
                    }
                }
                Text(Self.stageLabel(for: petState))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Gen \(petState.generation)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Text(petState.isAsleep ? "おやすみ" : "げんき")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private static func stageLabel(for state: PetState) -> String {
        let day = String(format: "%.1f", state.ageDays)
        switch state.stage {
        case .egg:      return "たまご · Day \(day)"
        case .child:    return "幼年期 · Day \(day)"
        case .adult:    return "成熟期 · Day \(day)"
        case .elder:    return "老年期 · Day \(day)"
        case .departed: return "告别 · Day \(day)"
        }
    }
}

private struct RoomBackground: View {
    var body: some View {
        ZStack {
            Color.black
            // Very subtle pixel floor line so the room still reads as a
            // "space" rather than a featureless void. Kept at ~4% white so
            // it's barely there.
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
                    .padding(.bottom, 70)
            }
        }
    }
}

// MARK: - Vitals

private struct VitalsStrip: View {
    @ObservedObject var petState: PetState

    var body: some View {
        HStack(spacing: 10) {
            StatusBar(label: "おなか", fill: petState.hunger, color: .orange)
            StatusBar(label: "きもち", fill: petState.mood, color: .pink)
            StatusBar(label: "げんき", fill: petState.energy, color: .green)
        }
    }
}

private struct StatusBar: View {
    let label: String
    let fill: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
                Text("\(Int(round(fill * 100)))")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                GeometryReader { geo in
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * fill))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Actions

private struct ActionBar: View {
    @ObservedObject var petState: PetState

    var body: some View {
        HStack(spacing: 10) {
            ActionButton(label: "喂食", symbol: "🍚") { petState.feed() }
            ActionButton(label: "玩耍", symbol: "🎈") { petState.play() }
            ActionButton(label: "休息", symbol: "💤") { petState.rest() }
        }
        .disabled(!petState.canInteract)
        .opacity(petState.canInteract ? 1.0 : 0.35)
    }
}

private struct ActionButton: View {
    let label: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(symbol)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sleep

private struct SleepOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 8) {
                Text("Z z z")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                Text("宠物睡着了")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
