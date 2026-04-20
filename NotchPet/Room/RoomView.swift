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
    /// Lets inline text editors (the pet-name field) ask the hosting
    /// non-activating panel to temporarily accept keyboard input.
    let onKeyboardFocusRequest: (Bool) -> Void
    @ObservedObject private var settings = AppSettings.shared
    @State private var isSettingsShowing: Bool = false
    @State private var isShopShowing: Bool = false
    @State private var isMarriageShowing: Bool = false
    @State private var isMemorialBookShowing: Bool = false
    @State private var editingName: String? = nil
    @FocusState private var nameFieldFocused: Bool
    /// Transient UI flag — true once the farewell animation has finished
    /// playing for the current departed→reborn cycle. Reset when the pet
    /// returns to `.egg` via `rebornAsNewGeneration()` so the next
    /// generation's death also gets a proper goodbye.
    @State private var farewellFinished: Bool = false

    /// True while the farewell animation is running — sprite fades in
    /// place and ascension particles rise from the pet's real position.
    private var isPlayingFarewell: Bool {
        petState.awaitingRebornConfirm && !farewellFinished
    }

    /// Pet sprite frame size. Sprites are now rendered onto a 26×26
    /// canvas (16×16 art + 5-pixel padding each side so animation
    /// offsets like bounce / held don't clip). Size 98 = 60 × 26/16,
    /// which keeps the visible animal at the same on-screen size as
    /// the old 16×16 sprite at 60pt.
    static let petSize: CGFloat = 98
    /// Hit / cursor area around the pet — slightly larger than the
    /// sprite so tiny taps near the silhouette still register.
    static let petHitSize: CGFloat = 137

    var body: some View {
        ZStack {
            RoomThemeBackground(themeID: inventory.activeRoomTheme)

            // Night moonlight tint — fades in during the 21:00–09:00
            // window so the room reads as evening even when the pet
            // itself is an egg / freshly hatched child still awake.
            NightTintOverlay(petState: petState)

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

            // Chrome: header + hearts + action bar pinned to top/bottom.
            // The Spacer region in the middle stays transparent to hit
            // testing so the pet sprite (layered above in its own
            // GeometryReader) still receives drags and taps.
            VStack(spacing: 14) {
                headerRow
                Spacer()
                HeartsStrip(petState: petState)
                    .padding(.horizontal, 20)
                ActionBar(petState: petState, onShake: onShake)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floor-anchored entities (furniture, pet, poop). One
            // GeometryReader fills the panel so every foot-anchored
            // thing shares the same `floorY` reference.
            GeometryReader { geo in
                let floorY = RoomGeometry.floorY(in: geo.size)
                // Sprite (petSize) is centred in the larger hit rect
                // (petHitSize). We want the sprite's visual bottom to
                // sit on floorY, so rest Y (centre of hit rect) is one
                // sprite-half above floor. `petFootInset` compensates
                // for any transparent padding below the visible feet
                // inside the sprite frame (positive ⇒ push pet down).
                let restY  = floorY - Self.petSize / 2 + RoomGeometry.petFootInset

                ZStack(alignment: .topLeading) {
                    FurnitureLayer(inventory: inventory)

                    ZStack {
                        // PetView is told not to apply its own movement
                        // offset — RoomView owns 2D positioning here so
                        // drag translations in y work consistently with
                        // the existing `petX` walking logic.
                        PetView(size: Self.petSize, petState: petState, applyMovement: false)
                            .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
                            // During farewell the sprite fades in-place
                            // so the ascending halos appear to rise from
                            // its actual spot instead of a duplicate
                            // sprite elsewhere.
                            .opacity(isPlayingFarewell ? 0 : 1)
                            .animation(.easeInOut(duration: 3.0),
                                       value: isPlayingFarewell)
                        // Block 6: feed/play feedback animation layered
                        // on top of the pet sprite. Re-inits each time
                        // `petState.actionAnimation` changes so the
                        // internal @State counters restart.
                        if let anim = petState.actionAnimation {
                            ActionAnimationOverlay(animation: anim, petSize: Self.petSize)
                                .id(ObjectIdentifier(petState).hashValue ^ anim.hashValue)
                        }
                    }
                    .frame(width: Self.petHitSize, height: Self.petHitSize)
                    .contentShape(Rectangle())
                    .position(x: geo.size.width / 2 + petState.petX,
                              y: restY + petState.petY)
                    .animation(petState.isBeingHeld ? nil : .easeInOut(duration: 0.3),
                               value: petState.petX)
                    .animation(petState.isBeingHeld ? nil : .spring(response: 0.45, dampingFraction: 0.6),
                               value: petState.petY)
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                if !petState.isBeingHeld { petState.startHold() }
                                petState.updateHold(translation: value.translation)
                            }
                            .onEnded { _ in petState.endHold() }
                    )
                    .onTapGesture { petState.reactToTap() }

                    // Poop piles — each pile is anchored at the room-
                    // relative xOffset captured when it spawned, so
                    // piles stay put instead of trailing the pet.
                    ForEach(petState.poopPiles) { pile in
                        PoopView(size: 24)
                            .position(
                                x: geo.size.width / 2 + pile.xOffset,
                                y: floorY - RoomGeometry.poopHalfHeight
                            )
                    }

                    // Sleep cue — pixel-style Zzz rising from just above
                    // the pet's head. Replaces the old full-screen
                    // overlay; anchored slightly to the right so it
                    // doesn't cover the sprite's face.
                    if petState.isAsleep {
                        SleepZzzOverlay()
                            .position(
                                x: geo.size.width / 2 + petState.petX + Self.petSize * 0.30,
                                y: restY - Self.petSize / 2 - 8
                            )
                    }

                    // Ascension particles — halos + wings rising from
                    // the pet's actual position during farewell. Placed
                    // here so it follows petX/petY just like the real
                    // sprite does.
                    if isPlayingFarewell {
                        AscensionParticleField()
                            .frame(width: 120, height: 140)
                            .position(
                                x: geo.size.width / 2 + petState.petX,
                                y: restY + petState.petY - 20
                            )
                    }

                    // Married partner — a static "ghost" sprite standing
                    // on the right side. Lives locally only; no live
                    // state sync. Sits slightly behind the main pet so
                    // interactions feel centered on the player's pet.
                    if let partner = petState.partner {
                        SpriteImage(
                            species: partner.species,
                            stage: .adult,
                            mode: .idle,
                            personality: partner.personality
                        )
                        .frame(width: Self.petSize, height: Self.petSize)
                        .shadow(color: Color.black.opacity(0.35), radius: 3, y: 2)
                        .position(
                            x: geo.size.width / 2 + 85,
                            y: restY
                        )
                    }

                    // Pending egg — shown between marriage + 1 day and
                    // egg + 1 day. Sits on the left side of the floor.
                    if let egg = petState.pendingEgg {
                        SpriteImage(
                            species: egg.species,
                            stage: .egg,
                            mode: .idle,
                            personality: nil
                        )
                        .frame(
                            width: Self.petSize * 0.78,
                            height: Self.petSize * 0.78
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                        .position(
                            x: geo.size.width / 2 - 85,
                            y: restY + 4
                        )
                    }

                    // Hatched baby — a child-stage sprite with inherited
                    // species + personality, sits where the egg used to
                    // be. Replaced by the new generation after the
                    // family farewell sequence.
                    if let baby = petState.pendingBaby {
                        SpriteImage(
                            species: baby.species,
                            stage: .child,
                            mode: .idle,
                            personality: baby.personality
                        )
                        .frame(
                            width: Self.petSize * 0.9,
                            height: Self.petSize * 0.9
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 3, y: 2)
                        .position(
                            x: geo.size.width / 2 - 85,
                            y: restY
                        )
                    }

                    // Head status cue — sick / hungry / sad / fly. Only
                    // one shows at a time; suppressed during sleep / egg
                    // / departed because those have dedicated overlays.
                    PetHeadStatusOverlay(petState: petState)
                        .position(
                            x: geo.size.width / 2 + petState.petX - Self.petSize * 0.25,
                            y: restY - Self.petSize / 2 - 12
                        )
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            if petState.awaitingRebornConfirm && !farewellFinished {
                FarewellOverlay(petState: petState) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        farewellFinished = true
                    }
                }
            } else if petState.awaitingRebornConfirm {
                MemorialCardOverlay(petState: petState)
            }

            if isShopShowing {
                ShopPanel(
                    inventory: inventory,
                    isShowing: $isShopShowing
                )
            }

            if isSettingsShowing {
                SettingsPanel(isShowing: $isSettingsShowing) {
                    isMemorialBookShowing = true
                }
            }

            if isMemorialBookShowing {
                MemorialBookPanel(isShowing: $isMemorialBookShowing)
            }

            if isMarriageShowing {
                MarriagePanel(
                    petState: petState,
                    isShowing: $isMarriageShowing
                )
            }

            if !settings.hasCompletedOnboarding {
                OnboardingOverlay(petState: petState) {
                    AppSettings.shared.hasCompletedOnboarding = true
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: petState.stage) { _, newStage in
            // Reset the farewell flag once the pet reincarnates so the
            // next generation's death will replay the goodbye animation.
            if newStage == .egg { farewellFinished = false }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if petState.stage != .egg {
                        nameView
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
                }
                Text(Self.stageLabel(for: petState))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    // Ring: only visible for single adult pets. One-click
                    // opens the marriage QR / scan panel.
                    if petState.stage == .adult && petState.partner == nil {
                        Button {
                            isMarriageShowing.toggle()
                        } label: {
                            HeaderIconView(kind: .ring, size: 14)
                        }
                        .buttonStyle(.plain)
                    }
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

    @ViewBuilder
    private var nameView: some View {
        if let draft = editingName {
            TextField("", text: Binding(
                get: { draft },
                set: { editingName = String($0.prefix(PetState.maxNameLength)) }
            ))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(minWidth: 40, maxWidth: 140)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.12))
                )
                .focused($nameFieldFocused)
                .onSubmit { commitNameEdit() }
                .onExitCommand { cancelNameEdit() }
                .onChange(of: nameFieldFocused) { _, focused in
                    if !focused { commitNameEdit() }
                }
        } else {
            Text(petState.name)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Non-activating panels don't become key automatically,
                    // so the TextField would never receive keystrokes. Ask
                    // the controller to temporarily accept keyboard focus
                    // before handing focus to the field.
                    onKeyboardFocusRequest(true)
                    editingName = petState.name
                    nameFieldFocused = true
                }
        }
    }

    private func commitNameEdit() {
        guard let draft = editingName else { return }
        petState.rename(to: draft)
        editingName = nil
        nameFieldFocused = false
        onKeyboardFocusRequest(false)
    }

    private func cancelNameEdit() {
        editingName = nil
        nameFieldFocused = false
        onKeyboardFocusRequest(false)
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

/// Shared room geometry — the canonical floor line that pet, furniture,
/// and poop all anchor to. Keeping it as a single source of truth means
/// any theme / layout tweak only needs one constant changed.
///
/// Coordinates are in the full 540×400 panel frame. `floorRatio` is the
/// fraction of the panel height occupied by the visible floor band (the
/// painted wood / tatami / grass strip of the theme). Space theme has
/// no indoor floor band — the line is then a logical anchor only.
enum RoomGeometry {
    /// Fraction of panel height occupied by the visible floor band.
    /// Must stay in sync with the per-theme `floorHeight` in
    /// `RoomTheme.swift` (Default / Washitsu).
    static let floorRatio: CGFloat = 0.30
    /// Y (inside the panel) of the wall-back furniture slot.
    /// Preserves the old centred `-95` from centre at a ~400pt panel.
    static let wallShelfY: CGFloat = 110
    /// Transparent padding below the sprite feet inside the 98pt pet
    /// frame. The 26×26 render canvas has 5 pixels of padding below
    /// the 16-row art; at 98pt / 26px ≈ 3.77pt per pixel, that's ~19pt
    /// of empty space below the visible feet. Positive petFootInset
    /// pushes the pet down so the feet still land on the floor line.
    static let petFootInset: CGFloat = 19
    /// Half-height of the poop sprite at size 24, used to bottom-anchor
    /// the poop pile on the floor line.
    static let poopHalfHeight: CGFloat = 12

    static func floorY(in size: CGSize) -> CGFloat {
        size.height * (1 - floorRatio)
    }
}

/// Block 6: renders placed furniture at slot positions anchored to the
/// shared floor line (`RoomGeometry`). Floor slots are bottom-anchored
/// to floor; the wall-back slot uses an independent wall-shelf Y.
private struct FurnitureLayer: View {
    @ObservedObject var inventory: PlayerInventory

    var body: some View {
        GeometryReader { geo in
            let floorY = RoomGeometry.floorY(in: geo.size)
            ZStack {
                ForEach(FurnitureSlot.allCases, id: \.self) { slot in
                    if let id = inventory.placedFurniture[slot] {
                        let size = Self.slotSize(slot)
                        FurnitureSpriteView(id: id, size: size)
                            .position(
                                x: Self.slotX(slot, in: geo.size),
                                y: Self.slotY(slot, size: size, floorY: floorY)
                            )
                    }
                }
            }
        }
    }

    private static func slotX(_ slot: FurnitureSlot, in size: CGSize) -> CGFloat {
        switch slot {
        case .floorLeft:  return size.width * 0.18
        case .floorRight: return size.width * 0.82
        case .wallBack:   return size.width * 0.5
        }
    }

    private static func slotY(_ slot: FurnitureSlot, size: CGFloat, floorY: CGFloat) -> CGFloat {
        switch slot {
        case .floorLeft, .floorRight:
            // Center of the sprite frame sits `size/2 + footInset` above floor.
            return floorY - size / 2 - Self.footInset(slot)
        case .wallBack:
            return RoomGeometry.wallShelfY
        }
    }

    /// Per-slot transparent padding below sprite feet inside its frame.
    /// Start at 0 — tune if individual furniture pieces visibly float.
    private static func footInset(_ slot: FurnitureSlot) -> CGFloat { 0 }

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

