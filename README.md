# SonicBattery

An iOS app that shows an animated Sonic-the-Hedgehog-style sprite in the Dynamic Island / Lock Screen (via a Live Activity), reacting to your phone's real battery state — charging, disconnecting, dropping 10%, or hitting 90%. Pick your character in-app; browse and preview every character's animations locally before committing one to the Island.

<!-- Demo video goes here — see "Adding the demo video" below -->

## Screenshots

### Character picker — all six characters

| Sonic | Shadow | Silver |
|---|---|---|
| ![Sonic](screenshots/picker-sonic.png) | ![Shadow](screenshots/picker-shadow.png) | ![Silver](screenshots/picker-silver.png) |

| Knuckles | Tails | Espio |
|---|---|---|
| ![Knuckles](screenshots/picker-knuckles.png) | ![Tails](screenshots/picker-tails.png) | ![Espio](screenshots/picker-espio.png) |

### Live Activity (Sonic)

| Dynamic Island | Lock Screen quote |
|---|---|
| ![Dynamic Island](screenshots/dynamic-island-sonic.png) | ![Lock screen](screenshots/lockscreen-sonic-quote.png) |

## Features

- **Live Activity / Dynamic Island** sprite that reacts to real battery events: charger connected (persistent "Rolling" animation while charging < 90%), charger disconnected, battery dropped 10%, battery crossed 90% while charging (one-time transformation). The Dynamic Island's corner also shows a Chaos Emerald in that character's own color instead of the default battery percentage.
- **Six fully-illustrated characters** — Sonic, Shadow, Silver, Knuckles, Tails, and Espio each have their own complete sprite set (idle, rolling, battery-drop reaction, 90% transformation), not placeholder art.
- **Character picker** — a swipeable carousel to browse and select from all six characters. Swiping only previews a character; nothing is live until you tap Select. The background gradient, text colors, and icons all re-theme to match whichever character is currently previewed.
- **Dedicated state-testing screen** — tap the icon next to Select/Stop to open a full page for previewing any character's Rolling / Battery Drop / 90% Transform animation, no need to check the Island.
- **Quote system** — a `Quotes.json` file of tagged quotes; each character pulls from its own tag by default, or you can override it per-character to borrow another character's quotes or go fully random, with an hourly/daily reshuffle option for random mode.
- **Daily character rotation** — an optional toggle (top-right icon) that randomly switches the active character once a day.
- **Shortcuts integration** — an App Intent (`RefreshSonicActivityIntent`) lets a Shortcuts Personal Automation ("When Charger Connected/Disconnected") silently launch or refresh the Live Activity in the background, without ever opening the app UI.
- **Background execution handling** — extended-execution requests on backgrounding, a periodic `BGTaskScheduler` refresh, and a local notification if background time runs out mid-charge.

## Requirements

- Xcode 16+ (uses Swift 5, iOS 17 deployment target)
- A physical iPhone with a Dynamic Island (iPhone 14 Pro or later) recommended for full testing. A recent Simulator can show the resting Live Activity state reasonably well (see screenshots above), but there's no way to simulate real battery events in Simulator, so burst animations (Rolling, Battery Drop, 90% Transform) still need a real device
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you ever change `project.yml` and need to regenerate `SonicBattery.xcodeproj` (`brew install xcodegen`)

## Getting started

1. Clone the repo and open `SonicBattery.xcodeproj` in Xcode.
2. Select the `SonicBattery` target → **Signing & Capabilities** → pick your Team under Automatically manage signing. Repeat for the `SonicBatteryWidgetExtension` target. A free Apple ID is enough for local device testing.
3. Plug in your iPhone, select it as the run destination, and hit Run.
4. On your phone, open the app and tap **Select** on a character in the carousel — that's what starts the Live Activity (there's no separate Start button).
5. Background the app (Home button / swipe) — the Dynamic Island only shows the sprite while the app *isn't* frontmost.

### Optional: Shortcuts automation (recommended)

For the Island to react to charger events reliably even when the app hasn't been opened in a while:

1. Shortcuts app → **Automation** tab → **+** → **Create Personal Automation** → **Charger** → **Connected**.
2. **New Blank Automation** → search "Sonic" → add **Refresh Sonic Battery Activity**.
3. Toggle **off** "Ask Before Running" (required for it to run silently).
4. Repeat for **Charger → Disconnected**.

## Adding new characters / sprites

Sprite naming follows a convention in `Shared/BurstAnimation.swift` and `Shared/SonicCharacter.swift`: each character has an `assetPrefix`, and sprite sheets are named `<assetPrefix>_<baseName><frame>` (e.g. `Shadow_RollingF0`). Frame counts are per-character (`BurstAnimation.frameCount(for:)`) since each character's art was drawn with its own number of frames — there's no requirement that a new character match Sonic's counts. Each character also has a `themeGradient` and `themeTextColor` in `SonicCharacter.swift` driving the picker screen's background and text colors, and a Chaos Emerald color (`chaosEmeraldImageName`) for its Dynamic Island corner icon.

## Known limitations (iOS platform constraints, not bugs)

- **8-hour Live Activity lifetime**: iOS auto-removes a Live Activity the app doesn't end, roughly 8 hours after it starts. The app schedules a local notification ~45 minutes before that to prompt a reopen.
- **No continuous background animation**: smooth frame-by-frame animation only happens while the app is foregrounded (or within ~30s of backgrounding, via an extended-execution grant). Fully backgrounded, the sprite advances a step only when something wakes the app (a Shortcuts trigger, or the periodic background refresh) — this is an iOS-wide restriction, not something any app can work around.
- **Dynamic Island hidden while the app is open**: iOS suppresses your own app's Live Activity content in the Island while that app is frontmost, by design.

## Project structure

```
SonicBattery/          Main app target — UI, battery monitoring, orchestration
SonicBatteryWidget/     Widget extension target — renders the Live Activity / Dynamic Island
Shared/                 Code + resources shared by both targets (models, Quotes.json, sprite assets)
project.yml             XcodeGen spec — source of truth for the Xcode project
```

## Adding the demo video

Will ADD VIDEO SOON
