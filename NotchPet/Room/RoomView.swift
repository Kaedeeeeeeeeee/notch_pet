import SwiftUI

/// Expanded popover content shown when the user clicks the notch strip.
/// Live status bars are bound to `PetState`; action buttons drive the
/// corresponding feed/play/rest mutations. Collapse is handled globally by
/// `NotchPanelController`'s dismiss monitors (click-outside or ESC) so this
/// view has no collapse affordance of its own.
struct RoomView: View {
    @ObservedObject var petState: PetState
    @ObservedObject var inventory: PlayerInventory
    let onShake: (NotchPanelController.ShakeIntensity) -> Void
    @ObservedObject private var settings = AppSettings.shared
    @State private var isSettingsShowing: Bool = false
    @State private var isShopShowing: Bool = false

    /// Block 6 polish: pet sprite shrunk from 120 → 60 so furniture
    /// has room to breathe behind it. Anything scaled relative to the
    /// pet uses this single constant.
    static let petSize: CGFloat = 60

    var body: some View {
        ZStack {
            RoomThemeBackground(themeID: inventory.activeRoomTheme)

            // Placed furniture, rendered between background and pet so
            // the pet visually sits on top of floor items.
            FurnitureLayer(inventory: inventory)

            // Header readability scrim: a darker gradient pinned to the
            // top edge so the white header text stays legible regardless
            // of which theme is active. The `.frame(maxHeight:alignment:
            // .top)` is what makes it pin correctly inside the ZStack
            // (default ZStack alignment is center).
            LinearGradient(
                colors: [
                    Color.black.opacity(0.80),
                    Color.black.opacity(0.70),
                    Color.black.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                headerRow
                Spacer()
                ZStack(alignment: .bottom) {
                    ZStack {
                        PetView(size: Self.petSize, petState: petState)
                            .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
                        // Block 6: feed/play feedback animation layered
                        // on top of the pet sprite. Re-inits each time
                        // `petState.actionAnimation` changes so the
                        // internal @State counters restart.
                        if let anim = petState.actionAnimation {
                            ActionAnimationOverlay(animation: anim, petSize: Self.petSize)
                                .id(ObjectIdentifier(petState).hashValue ^ anim.hashValue)
                        }
                    }
                    // Block 6: poop pile on the room floor. Offset each
                    // pile horizontally so multiple poops don't stack.
                    HStack(spacing: 3) {
                        ForEach(0..<petState.poops, id: \.self) { _ in
                            PoopView(size: 24)
                        }
                    }
                    .offset(x: petState.petX + Self.petSize * 0.55, y: 4)
                }
                Spacer()
                HeartsStrip(petState: petState)
                    .padding(.horizontal, 20)
                ActionBar(petState: petState, onShake: onShake)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if petState.isAsleep {
                SleepOverlay()
            }

            if petState.awaitingRebornConfirm {
                RebornConfirmOverlay(petState: petState)
            }

            if isShopShowing {
                ShopPanel(
                    inventory: inventory,
                    isShowing: $isShopShowing
                )
            }

            if isSettingsShowing {
                SettingsPanel(isShowing: $isSettingsShowing)
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
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.black.opacity(0.35))
                            )
                    }
                }
                Text(Self.stageLabel(for: petState))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Button {
                        isSettingsShowing.toggle()
                    } label: {
                        HeaderIconView(kind: .settings, size: 14)
                    }
                    .buttonStyle(.plain)
                    Button {
                        isShopShowing.toggle()
                    } label: {
                        HeaderIconView(kind: .shop, size: 14)
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 3) {
                        HeaderIconView(kind: .coin, size: 12)
                        Text("\(inventory.coins)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                Text("Gen \(petState.generation)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private static func stageLabel(for state: PetState) -> String {
        let day = String(format: "%.1f", state.ageDays)
        let lang = AppSettings.shared.language
        switch state.stage {
        case .egg:      return "\(lang.stageEgg) · Day \(day)"
        case .child:    return "\(lang.stageChild) · Day \(day)"
        case .adult:    return "\(lang.stageAdult) · Day \(day)"
        case .elder:    return "\(lang.stageElder) · Day \(day)"
        case .departed: return "\(lang.stageDeparted) · Day \(day)"
        }
    }
}

/// Block 6: renders placed furniture at fixed slot positions inside
/// the room. Each slot has a hand-picked (x, y) offset relative to the
/// view's centre that keeps the layout readable with the pet sprite.
private struct FurnitureLayer: View {
    @ObservedObject var inventory: PlayerInventory

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(FurnitureSlot.allCases, id: \.self) { slot in
                    if let id = inventory.placedFurniture[slot] {
                        FurnitureSpriteView(id: id, size: Self.slotSize(slot))
                            .position(
                                x: geo.size.width / 2 + Self.slotOffset(slot).x,
                                y: geo.size.height / 2 + Self.slotOffset(slot).y
                            )
                    }
                }
            }
        }
    }

    private static func slotOffset(_ slot: FurnitureSlot) -> CGPoint {
        // Block 6 widened room (540×400): spread floor slots further out
        // and pull the wall-back slot up a touch.
        switch slot {
        case .floorLeft:  return CGPoint(x: -170, y: 55)
        case .floorRight: return CGPoint(x: 170, y: 55)
        case .wallBack:   return CGPoint(x: 0, y: -95)
        }
    }

    private static func slotSize(_ slot: FurnitureSlot) -> CGFloat {
        switch slot {
        case .floorLeft, .floorRight: return 32
        case .wallBack:               return 34
        }
    }
}

// MARK: - Vitals

/// Block 6: discrete heart rows for hunger + happy, plus a small
/// weight readout. Replaces the Block 2 `VitalsStrip` 3-bar layout.
private struct HeartsStrip: View {
    @ObservedObject var petState: PetState
    private var lang: AppLanguage { AppSettings.shared.language }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            HeartsRow(
                label: lang.hungerLabel,
                filled: petState.hunger,
                max: PetState.maxHearts,
                tint: Color(red: 1.00, green: 0.42, blue: 0.48)
            )
            HeartsRow(
                label: lang.happyLabel,
                filled: petState.happy,
                max: PetState.maxHearts,
                tint: Color(red: 1.00, green: 0.70, blue: 0.30)
            )
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(lang.weightLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(petState.weight)g")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Actions

private struct ActionBar: View {
    @ObservedObject var petState: PetState
    let onShake: (NotchPanelController.ShakeIntensity) -> Void
    private var lang: AppLanguage { AppSettings.shared.language }

    var body: some View {
        HStack(spacing: 8) {
            ActionButton(
                label: lang.feedAction,
                icon: .feed,
                enabled: petState.canInteract
            ) {
                petState.feed()
                onShake(.light)
            }
            ActionButton(
                label: lang.playAction,
                icon: .play,
                enabled: petState.canInteract
            ) {
                petState.play()
                onShake(.light)
            }
            ActionButton(
                label: lang.medicineAction,
                icon: .medicine,
                enabled: petState.canInteract && petState.sick
            ) {
                petState.takeMedicine()
                onShake(.light)
            }
            ActionButton(
                label: lang.cleanAction,
                icon: .clean,
                enabled: petState.canInteract && petState.poops > 0
            ) {
                petState.clean()
                onShake(.light)
            }
        }
    }
}

private struct ActionButton: View {
    let label: String
    let icon: ActionIconView.Kind
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ActionIconView(kind: icon, size: 22)
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.35)
    }
}

// MARK: - Sleep

private struct SleepOverlay: View {
    private var lang: AppLanguage { AppSettings.shared.language }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 8) {
                Text("Z z z")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                Text(lang.petSleeping)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Reborn confirmation

private struct RebornConfirmOverlay: View {
    @ObservedObject var petState: PetState
    private var lang: AppLanguage { AppSettings.shared.language }

    var body: some View {
        ZStack {
            Color.black.opacity(0.70).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(lang.departFarewellTitle(name: petState.name))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(lang.departFarewellBody)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                Button {
                    petState.confirmReborn()
                } label: {
                    Text(lang.departRebornButton)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(32)
        }
        .onTapGesture { }  // swallow taps to prevent pass-through
    }
}
