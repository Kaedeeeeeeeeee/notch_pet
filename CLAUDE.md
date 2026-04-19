# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Notch Pet — a macOS pixel-art virtual pet (Tamagotchi-style) that lives inside the MacBook notch. Swift + AppKit + SwiftUI hybrid. The product design doc is `notch-pet-product-design.md` (Chinese); the dev log is `DEVELOPMENT_LOG.md`.

## Build & Run

```bash
# Regenerate Xcode project from project.yml (required after adding/removing files)
xcodegen generate

# Build (debug)
xcodebuild -project NotchPet.xcodeproj -scheme NotchPet -configuration Debug build

# Build (release)
xcodebuild -project NotchPet.xcodeproj -scheme NotchPet -configuration Release build

# Run the built app (must be on a MacBook with a notch)
open build/Build/Products/Debug/NotchPet.app
```

There are no tests yet. No linter is configured.

## Debug Tuning via Environment Variables

All timing constants have env-var overrides and fast DEBUG defaults so a full lifecycle plays out in ~3 minutes:

| Env var | DEBUG default | Release default | What it controls |
|---------|--------------|-----------------|------------------|
| `NOTCHPET_DAY_SECONDS` | 20s | 86400s | Active seconds per pet-day |
| `NOTCHPET_HUNGER_SEC` | 20s | 300s | Seconds per hunger heart lost |
| `NOTCHPET_HAPPY_SEC` | 30s | 480s | Seconds per happy heart lost |
| `NOTCHPET_POOP_DELAY` | 25s | 300s | Seconds after feeding before poop spawns |
| `NOTCHPET_NEGLECT_SEC` | 15s | 120s | Seconds at 0 vitals before sickness |
| `NOTCHPET_POOP_SICK_SEC` | 20s | 180s | Seconds poop sits before causing sickness |
| `NOTCHPET_DECAY_SPEEDUP` | 1.0 | 1.0 | Global multiplier on all decay |
| `NOTCHPET_NEWBORN_GRACE_SEC` | 10s | 3600s | Active grace after hatch before night sleep applies |
| `NOTCHPET_ELDER_HUNGER_DEATH` | 10s | 43200s | Elder starvation death threshold |
| `NOTCHPET_ELDER_HAPPY_DEATH` | 20s | 86400s | Elder sadness death threshold |
| `NOTCHPET_ELDER_SICK_DEATH` | 20s | 86400s | Elder sickness death threshold |

Set these in the Xcode scheme's "Arguments > Environment Variables" or export them before running.

## Sprite Asset Pipeline

Sprites are generated via Aseprite Lua scripts, not hand-drawn in the editor:

1. `tools/sprites/gen_pet.lua` — generates the pet spritesheet (form × stage × mode matrix, 82 tags / 287 frames)
2. Aseprite CLI (`tools/aseprite/build/bin/aseprite`) exports packed PNG + JSON
3. Output lands in `NotchPet/Assets/Sprites/` as `pet.png` + `pet.json` (and `furniture.png` + `furniture.json`)
4. XcodeGen bundles the `Assets/Sprites/` and `Assets/Audio/` directories as folder references (not individual resources)

Tag naming convention in the spritesheet: `<form>_<stage>_<mode>` (e.g. `cheerful_adult_happy`). Pre-personality stages use `egg_idle`, `child_<mode>`, `departed_idle`.

## Architecture

**Window system** — The app is `LSUIElement` (no Dock icon). A custom `NSPanel` subclass (`NotchPanel`) with `[.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]` style mask is positioned over the MacBook's physical notch. `NotchPanelController` manages expand/collapse animation, screen-parameter observation, and dismiss monitors (ESC / click-outside). SwiftUI views are hosted via `FirstMouseHostingView` (an `NSHostingView` subclass that fixes `acceptsFirstMouse` for non-activating panels).

**Two UI layers:**
- **Collapsed strip** — sits flush over the notch. Pet sprite on the left extension, status icon on the right. Clicking expands.
- **Expanded room** (540×400) — pixel-art room with pet, furniture, vitals hearts, action buttons. Overlays for sleep, shop/settings panels.

**Gameplay model** — `PetState` (`@MainActor ObservableObject`) holds all mutable game state. Vitals are discrete 0–4 integer hearts. `TimeService` runs a 1 Hz timer that drives `applyDecay`, `runCareTick`, and `advanceLifecycle` only while the computer is active (pauses on sleep/lock/screen-off via `NSWorkspace` notifications). Night sleep (21:00–09:00) freezes everything.

**Lifecycle** — egg → child → adult → elder → departed → reborn. Elder stage is open-ended; death only from sustained neglect. `rebornAsNewGeneration()` resets `PetState` in-place (no view reconstruction).

**Personality** — 6 traits (cheerful/shy/aloof/gluttonous/lazy/grumpy), derived from `CareHistory` at child→adult transition. Each trait has gameplay modifiers (`PersonalityBehavior.swift`) and a dedicated sprite form.

**Persistence** — `PetStateStore` saves to `~/Library/Application Support/com.notchpet.NotchPet/state.json` (schema v3, with v2 migration). `InventoryStore` saves `inventory.json` alongside it. Inventory (coins, rooms, furniture) survives across generations.

**Economy** — Coins earned from care actions (feed/play +1, clean +2, medicine +3, stage transition +10, depart +20). Spent in the shop on room themes (4 available) and furniture (6 items, 3 placement slots).

**Sound** — `SoundPlayer` wraps `AudioToolbox` system sounds. 10 WAV files in `Assets/Audio/`, 8-bit chiptune style.

## Key Pitfalls (from dev log)

- `NSScreen.main` is NOT the built-in screen when an external display is set as primary. Always use `NSScreen.builtInNotchedScreen` (custom extension).
- SwiftUI `.onTapGesture` does not reliably fire on `.nonactivatingPanel`. Collapsed-strip clicks are handled in AppKit via `FirstMouseHostingView.mouseDown`, not SwiftUI gestures.
- The expanded panel (540pt wide) exceeds the physical notch width (~185pt). This is intentional — it covers menu bar area on both sides.

## Current Status

Blocks 0–6 complete (core Tamagotchi loop, sprites, personality, economy, room/furniture). Not yet implemented: social pairing (QR code + CloudKit), breeding/genetics, wearable items, App Store submission.
