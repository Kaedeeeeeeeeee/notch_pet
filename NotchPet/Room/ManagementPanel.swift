import SwiftUI

/// Shop overlay. Triggered by the shop button in the RoomView header.
/// Tabs for room themes, furniture, and clothing — each showing a grid
/// of items with name, price, owned/equipped state, and a purchase/equip
/// button. Lives inside RoomView's ZStack so it never creates a new window.
struct ShopPanel: View {
    @ObservedObject var inventory: PlayerInventory
    @Binding var isShowing: Bool
    @ObservedObject private var settings = AppSettings.shared

    @State private var selectedTab: Tab = .rooms

    enum Tab: CaseIterable {
        case rooms, furniture, clothes

        func label(_ lang: AppLanguage) -> String {
            switch self {
            case .rooms: return lang.roomsTab
            case .furniture: return lang.furnitureTab
            case .clothes: return lang.clothesTab
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                tabBar
                content
                Spacer()
            }
        }
        .onTapGesture { /* swallow taps to block pass-through */ }
    }

    private var header: some View {
        HStack {
            Text(settings.language.shopTitle)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 4) {
                Text("🪙")
                    .font(.system(size: 11))
                Text("\(inventory.coins)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
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

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.label(settings.language))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selectedTab == tab
                                    ? Color.white.opacity(0.18)
                                    : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .rooms:
            RoomThemesTab(inventory: inventory)
        case .furniture:
            FurnitureTab(inventory: inventory)
        case .clothes:
            ClothesTab()
        }
    }
}

// MARK: - Rooms tab

private struct RoomThemesTab: View {
    @ObservedObject var inventory: PlayerInventory

    var body: some View {
        VStack(spacing: 6) {
            ForEach(RoomThemeDefinition.all) { theme in
                RoomThemeRow(inventory: inventory, theme: theme)
            }
        }
        .padding(.horizontal, 14)
    }
}

private struct RoomThemeRow: View {
    @ObservedObject var inventory: PlayerInventory
    let theme: RoomThemeDefinition
    private var lang: AppLanguage { AppSettings.shared.language }

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            RoomThemeBackground(themeID: theme.id)
                .frame(width: 52, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.displayName)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(priceLabel)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            actionButton
        }
        .padding(.vertical, 4)
    }

    private var owned: Bool { inventory.ownedRoomThemes.contains(theme.id) }
    private var active: Bool { inventory.activeRoomTheme == theme.id }

    private var priceLabel: String {
        if active { return lang.inUse }
        if owned { return lang.owned }
        return "🪙 \(theme.price)"
    }

    @ViewBuilder
    private var actionButton: some View {
        if active {
            Text("✓")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.green)
                .frame(width: 56, height: 24)
        } else if owned {
            Button {
                inventory.equipRoomTheme(theme.id)
            } label: {
                Text(lang.equipButton)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        } else {
            Button {
                _ = inventory.purchaseRoomTheme(theme.id, price: theme.price)
            } label: {
                Text(lang.buyButton)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(inventory.canAfford(theme.price)
                                ? Color(red: 0.20, green: 0.55, blue: 0.30)
                                : Color.white.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!inventory.canAfford(theme.price))
        }
    }
}

// MARK: - Furniture tab

private struct FurnitureTab: View {
    @ObservedObject var inventory: PlayerInventory

    var body: some View {
        VStack(spacing: 4) {
            ForEach(FurnitureCatalog.all) { item in
                FurnitureRow(inventory: inventory, item: item)
            }
        }
        .padding(.horizontal, 14)
    }
}

private struct FurnitureRow: View {
    @ObservedObject var inventory: PlayerInventory
    let item: FurnitureDefinition
    private var lang: AppLanguage { AppSettings.shared.language }

    var body: some View {
        HStack(spacing: 10) {
            FurnitureSpriteView(id: item.id, size: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            actionButton
        }
        .padding(.vertical, 3)
    }

    private var owned: Bool { inventory.ownedFurniture.contains(item.id) }
    private var placedSlot: FurnitureSlot? {
        inventory.placedFurniture.first(where: { $0.value == item.id })?.key
    }

    private var subtitle: String {
        if let slot = placedSlot {
            return "\(lang.placed) · \(slotLabel(slot))"
        }
        if owned { return lang.owned }
        return "🪙 \(item.price)"
    }

    private func slotLabel(_ slot: FurnitureSlot) -> String {
        switch slot {
        case .floorLeft:  return lang.floorLeft
        case .floorRight: return lang.floorRight
        case .wallBack:   return lang.wallBack
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if placedSlot != nil {
            Button {
                if let slot = placedSlot {
                    inventory.removeFurniture(from: slot)
                }
            } label: {
                Text(lang.putAway)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        } else if owned {
            // Pick the first allowed slot that's free. Keeps the UI
            // one-click for MVP; if every allowed slot is occupied we
            // evict whatever's in the preferred slot.
            Button {
                placeInFirstFreeSlot()
            } label: {
                Text(lang.placeButton)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.25, green: 0.45, blue: 0.70))
                    )
            }
            .buttonStyle(.plain)
        } else {
            Button {
                _ = inventory.purchaseFurniture(item.id, price: item.price)
            } label: {
                Text(lang.buyButton)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(inventory.canAfford(item.price)
                                ? Color(red: 0.20, green: 0.55, blue: 0.30)
                                : Color.white.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!inventory.canAfford(item.price))
        }
    }

    private func placeInFirstFreeSlot() {
        // Prefer an empty slot from the item's allowed list.
        for slot in item.allowedSlots {
            if inventory.placedFurniture[slot] == nil {
                inventory.placeFurniture(item.id, in: slot)
                return
            }
        }
        // All allowed slots full — evict the first and place.
        if let first = item.allowedSlots.first {
            inventory.placeFurniture(item.id, in: first)
        }
    }
}

// MARK: - Clothes tab (placeholder)

private struct ClothesTab: View {
    private var lang: AppLanguage { AppSettings.shared.language }

    var body: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 30)
            Text("🧵")
                .font(.system(size: 24))
            Text(lang.comingSoon)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            Text(lang.moreClothes)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Settings panel

struct SettingsPanel: View {
    @Binding var isShowing: Bool
    @ObservedObject private var settings = AppSettings.shared

    private var lang: AppLanguage { settings.language }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                settingsList
                Spacer()
            }
        }
        .onTapGesture { /* swallow taps */ }
    }

    private var header: some View {
        HStack {
            Text(lang.settingsTitle)
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

    private static let activeGreen = Color(red: 0.22, green: 0.50, blue: 0.28)
    private static let dimGreen = Color(red: 0.14, green: 0.30, blue: 0.18)

    private var settingsList: some View {
        VStack(spacing: 2) {
            // Volume
            PixelVolumeRow(
                icon: .volume,
                label: lang.volumeLabel,
                value: $settings.soundVolume
            )

            // Shake
            PixelToggleRow(
                icon: .shake,
                label: lang.shakeLabel,
                isOn: $settings.shakeEnabled
            )

            // Language
            settingsRow(Color.white.opacity(0.06)) {
                HStack(spacing: 8) {
                    HeaderIconView(kind: .language, size: 14)
                    Text(lang.languageLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(AppLanguage.allCases, id: \.self) { option in
                            Button {
                                settings.language = option
                            } label: {
                                Text(option.displayName)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(settings.language == option
                                                ? Color.white.opacity(0.22)
                                                : Color.white.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer().frame(height: 8)

            // Quit
            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 8) {
                    Text("⏻")
                        .font(.system(size: 12))
                    Text(lang.quitApp)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
    }

    private func settingsRow<Content: View>(
        _ fill: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(fill)
            )
    }
}

// MARK: - Custom pixel-art volume bar

/// 10-segment retro volume bar. Tap a segment to set level; segments
/// fill green from left up to the current value.
private struct PixelVolumeRow: View {
    let icon: HeaderIconView.Kind
    let label: String
    @Binding var value: Float

    private static let segments = 10
    private static let filled = Color(red: 0.30, green: 0.65, blue: 0.38)
    private static let empty = Color.white.opacity(0.10)
    private static let rowBg = Color(red: 0.12, green: 0.22, blue: 0.14)

    private var filledCount: Int {
        Int((value * Float(Self.segments)).rounded())
    }

    var body: some View {
        HStack(spacing: 8) {
            HeaderIconView(kind: icon, size: 14)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            HStack(spacing: 2) {
                ForEach(0..<Self.segments, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < filledCount ? Self.filled : Self.empty)
                        .frame(height: 10)
                        .onTapGesture {
                            value = Float(i + 1) / Float(Self.segments)
                        }
                }
            }
            Text("\(Int(value * 100))")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 26, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(value > 0 ? Self.rowBg : Color.white.opacity(0.06))
        )
    }
}

// MARK: - Custom pixel-art toggle

/// ON / OFF pill with green row background when active.
private struct PixelToggleRow: View {
    let icon: HeaderIconView.Kind
    let label: String
    @Binding var isOn: Bool

    private static let onColor = Color(red: 0.30, green: 0.65, blue: 0.38)
    private static let offColor = Color.white.opacity(0.18)
    private static let rowOn = Color(red: 0.12, green: 0.22, blue: 0.14)
    private static let rowOff = Color.white.opacity(0.06)

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                HeaderIconView(kind: icon, size: 14)
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                // Pill-shaped ON/OFF indicator
                ZStack {
                    Capsule()
                        .fill(isOn ? Self.onColor : Self.offColor)
                        .frame(width: 36, height: 16)
                    Text(isOn ? "ON" : "OFF")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOn ? Self.rowOn : Self.rowOff)
            )
        }
        .buttonStyle(.plain)
    }
}
