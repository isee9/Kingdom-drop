# Kingdom Drop

**Build. Clear. Conquer.**

An original block-puzzle game for Android and iOS, built in Flutter. Drop
shapes onto a 7×7 board, clear rows, columns and 3×3 regions, and spend the
crowns you earn rebuilding ten ruined kingdoms.

Everything in this repository is original: the code, the rules and the
artwork. The painted art in `assets/art/` was made for this project and is
sliced from the source sheets in `art_src/`; everything not covered by it —
buttons, panels, frames, the board, all display text — is drawn in code. No
third-party artwork, audio, text or level data is used anywhere.

---

> **Publishing it?** [`LAUNCH_GUIDE.md`](LAUNCH_GUIDE.md) is a step-by-step
> walkthrough of getting this onto Google Play, written for someone who has
> never published an app. This README is the developer reference.

## Contents

- [What this is](#what-this-is)
- [Technology](#technology)
- [Getting started](#getting-started)
- [Running the game](#running-the-game)
- [Running the tests](#running-the-tests)
- [Project layout](#project-layout)
- [How the game works](#how-the-game-works)
- [Where to change things](#where-to-change-things)
  - [Economy values](#economy-values)
  - [Kingdom values](#kingdom-values)
  - [Application ID and app name](#application-id-and-app-name)
  - [Art](#art)
  - [Sound](#sound)
- [Enabling real ads](#enabling-real-ads)
- [Enabling real in-app purchases](#enabling-real-in-app-purchases)
- [Release builds](#release-builds)
- [What you still need to supply](#what-you-still-need-to-supply)
- [Known MVP limitations](#known-mvp-limitations)
- [Release checklist](#release-checklist)

---

## What this is

A complete, playable MVP:

- **Core loop** — 7×7 board, three pieces at a time, drag and drop, row /
  column / 3×3 region clears, combo scoring, honest game-over detection.
- **Progression** — crowns, ten kingdoms with five upgrades each, player
  levels, achievements, a daily reward streak and a daily challenge.
- **Economy** — gold coins, four boosters, continues, chests.
- **Monetisation architecture** — rewarded and interstitial ads plus in-app
  purchases, both behind interfaces, both shipping with working mock
  implementations so the whole game is testable with no store account.
- **Polish** — particles, combo animation, floating score, screen shake,
  haptics, and a first-launch intro and tutorial.

---

## Technology

| Piece | Choice | Why |
| --- | --- | --- |
| Framework | Flutter (stable, 3.44+) | One codebase for both stores. |
| Board rendering | `CustomPainter` | Flutter's gesture system hit-tests drags far better than routing pointer events through a game loop, and the painter repaints from a single `Listenable`. |
| Particles / FX | [Flame](https://pub.dev/packages/flame) | A ready-made particle system with lifespans and automatic cleanup, rendering on its own surface so bursts never rebuild the widget tree mid-drag. |
| Persistence | `shared_preferences` | One JSON document behind a `StorageRepository` interface, so swapping in a file or a cloud save later touches one class. |
| Audio | `audioplayers` | Every call is guarded; the game runs silently when no audio assets are bundled. |
| State | `ChangeNotifier` + `InheritedWidget` | The app has one shared model (the player profile) and a per-run controller. A state-management package would be more machinery than the problem needs. |

The game engine (`lib/game/engine/`) imports no Flutter at all. Every rule is
plain Dart, which is why it can be tested exhaustively without a widget binding.

---

## Getting started

### 1. Install Flutter

If you do not already have it, follow the official guide for your platform:
<https://docs.flutter.dev/get-started/install>. In short:

```bash
# macOS (recommended for iOS work)
brew install --cask flutter

# or download the SDK archive and put it on your PATH
export PATH="$PATH:/path/to/flutter/bin"
```

Then check your setup:

```bash
flutter --version     # needs 3.44 or newer
flutter doctor        # fix anything it flags for the platforms you target
```

`flutter doctor` must show a green tick for **Android toolchain** to build for
Android, and for **Xcode** to build for iOS. Xcode is macOS-only — iOS builds
cannot be produced on Linux or Windows.

### 2. Install dependencies

```bash
cd Kingdom-drop
flutter pub get
```

---

## Running the game

```bash
flutter devices                 # list what is connected
flutter run                     # run on the only/default device
flutter run -d <device-id>      # pick a specific one
```

**Android:** enable Developer Options and USB debugging on the handset, or
start an emulator from Android Studio, then `flutter run`.

**iOS:** open `ios/Runner.xcworkspace` in Xcode once and set your signing team
(see [What you still need to supply](#what-you-still-need-to-supply)), then
`flutter run -d <your-iphone>`. A simulator needs no signing team.

**Desktop (development convenience):** a Linux desktop target is checked in and
was used to develop and verify the game. It is **not** a shipping target and is
not maintained as one — it exists so the game can be launched and inspected
quickly without a handset:

```bash
flutter run -d linux
```

The window opens at phone proportions (430×932).

### Playing it in a browser

A web target is also checked in, purely so the game can be tried without a
device. It is a convenience, not a shipping platform.

```bash
flutter run -d chrome
```

Or build it and serve the folder — this needs no Flutter on the machine doing
the serving, so it is the easiest way to hand the game to someone else:

```bash
flutter build web --release --no-web-resources-cdn
cd build/web && python3 -m http.server 8000
# then open http://localhost:8000
```

`--no-web-resources-cdn` bundles CanvasKit into the build instead of fetching
it from Google's CDN at runtime, so the game works on a locked-down network.
Flutter still fetches the **Roboto** font from `fonts.gstatic.com` on first
load; with no internet the game renders correctly but shows no text.

On a screen wider than 480 logical pixels the app centres itself in a
phone-width column rather than stretching — a tray spread across a desktop
window would put the pieces out of thumb reach. Chrome's device toolbar
(F12 → phone icon) gives an accurate phone preview.

Web saves go to browser local storage, separate from any device progress.

---

## Running the tests

```bash
flutter test                    # the whole suite
flutter test test/engine        # just the game rules
flutter test --coverage         # with coverage output in coverage/
flutter analyze                 # static analysis; should report no issues
```

The suite covers piece placement and rejection, every clear type and
combination, score and combo calculation, game-over detection, piece
generation fairness, crown/coin/XP conversion, kingdom progression, the
daily-reward date logic (including a device clock moved backwards), booster
consumption, coin spending, save/load round-tripping, schema migrations,
corrupt-save tolerance, and the game screen's layout and drag behaviour at
three screen sizes.

---

## Project layout

```
lib/
  app/            root widget, lifecycle, save flushing
  audio/          AudioService — sound hooks, silent when no assets
  core/
    config/       app, economy and kingdom configuration
    utils/        formatting helpers
  economy/        PlayerService — the single source of truth for the profile
  game/
    engine/       pure Dart rules: board, shapes, generator, scoring
    controller/   GameController — bridges the engine to the UI
    widgets/      board, tray, HUD, booster bar, block painting
    fx/           Flame particle layer
  models/         save data, boosters, achievements, daily state
  monetisation/   AdService, PurchaseService, product catalogue
  progression/    levels, kingdoms, chests, daily reward and challenge
  screens/        one folder per screen
  services/       analytics, haptics, service locator
  storage/        StorageRepository, SharedPreferences impl, debouncing
  theme/          colours, text styles, spacing, ThemeData
  widgets/        shared UI kit (buttons, cards, icons, logo)
assets/
  art/            painted art, generated by tool/slice_art.py — do not hand-edit
art_src/          the source art sheets the above is sliced from
tool/
  slice_art.py          cuts art_src/ sheets into assets/art/
  generate_icons.dart   resizes the app icon into every platform size
test/
  engine/ services/ storage/ widget/
```

---

## How the game works

### The board and the 3×3 rule

Seven does not divide by three, so the classic "every 3×3 block clears" rule
cannot tile a 7×7 board. Kingdom Drop uses **four fixed 3×3 quadrants** pinned
to the corners, with row 3 and column 3 forming a region-free cross:

```
A A A | B B B     quadrants occupy rows/cols 0-2 and 4-6
A A A | B B B     row 3 and column 3 are the "cross"
A A A | B B B
- - - + - - -
C C C | D D D
C C C | D D D
C C C | D D D
```

No cell belongs to two quadrants, so the rule is unambiguous, and the UI draws
it as four tinted plates split by a visible cross. Cells on the cross still
count toward row and column clears, which makes the middle lane the natural
place to dump an awkward piece.

### Fair piece generation

`ShapeGenerator` never deals a set where nothing fits. It rolls a weighted set,
checks it against the live board, re-rolls a bounded number of times, and if
still nothing fits, substitutes the largest piece that genuinely does. As the
board fills past 45% occupancy, large shapes are progressively down-weighted —
never to zero. The generator does not look past the first piece, so the board
can still close up and the run ends honestly.

### Scoring

10 points per block placed; 100 / 300 / 600 / 1000… for simultaneous clears;
a bonus for clearing in more than one direction at once; and a combo ladder
(×1 → ×1.25 → ×1.5 → ×2 → ×2.5 → ×3) that survives two non-clearing placements
before resetting.

---

## Where to change things

### Economy values

**`lib/core/config/economy_config.dart`** — every tunable number lives here and
nowhere else: points per block, clear values, the combo ladder, crown and coin
conversion rates, the XP curve, level rewards, continue cost, booster prices,
starting boosters, coin pack sizes, starter pack contents, the daily reward
table, challenge rewards and chest reward bands.

Balancing the game means editing this one file. If you find a reward or price
written anywhere else, that is a bug — move it here.

### Kingdom values

**`lib/core/config/kingdom_config.dart`** — the ten kingdoms, their names,
descriptions, colour palettes and upgrade ladders.

Upgrade costs are generated from a base ladder (`25, 40, 60, 90, 130`) scaled
per kingdom, rounded to the nearest 5 crowns. To change the curve, edit
`_baseCosts` or `_kingdomScale`. To add a kingdom, append a `_build(...)` entry
— nothing else needs to change; the UI, progression and save format all read
from this list, and progress is keyed by kingdom **id** so reordering the list
cannot corrupt an existing save.

`KingdomDefinition` already has `fromJson`/`toJson`, so the whole table can be
moved to a JSON asset or remote config later without touching any consumer.

### Application ID and app name

The bundle identifier appears in three places and **all three must match**:

| Where | File |
| --- | --- |
| Dart | `lib/core/config/app_config.dart` → `AppConfig.bundleId` |
| Android | `android/app/build.gradle.kts` → `applicationId` and `namespace` |
| iOS | Xcode → Runner target → Signing & Capabilities → Bundle Identifier |

The placeholder is `com.yourcompany.kingdomdrop`. Change it before your first
upload — on both stores an application ID is permanent once published.

The **display name** shown under the icon:

- Android: `android/app/src/main/AndroidManifest.xml` → `android:label`
- iOS: `ios/Runner/Info.plist` → `CFBundleDisplayName`
- In-app: `lib/core/config/app_config.dart` → `AppConfig.appName`

### Art

Two layers, and the split matters when you go to change something.

**Painted art** lives in `assets/art/` and is *generated* — do not edit those
files by hand. The originals are in `art_src/`, and `tool/slice_art.py` cuts
them into the individual assets the app loads: it crops each element off its
sheet, keys out the painted backdrop, trims to content and writes optimised
PNGs and JPEGs. Re-run it after changing anything in `art_src/`:

```bash
pip install pillow numpy scipy
python3 tool/slice_art.py
```

It is deterministic, so running it twice produces the same bytes and the
generated assets can safely be committed.

| Painted asset | Used by |
| --- | --- |
| `backgrounds/{home,game,kingdom,menu}.jpg` | `GameBackground`, one per `ArtScene` |
| `tiles/tile_*.png` | every block on the board, in the tray and under the finger |
| `icons/*.png` | crowns, coins, XP, chests, the calendar, the four boosters |
| `kingdoms/keep_{ruined,partial,restored}.png` | the kingdom diorama |
| `branding/logo.png` | splash and home |
| `branding/app_icon.png` | the source for every launcher and store icon |

Every path is declared once in **`lib/theme/app_art.dart`** — nothing else in
the app spells one out. Each of them also has a code-drawn fallback, so the app
still builds, runs and passes its tests with `assets/art/` deleted; it just
looks plainer.

**Code-drawn art** is everything else, and it is still where most of the look
comes from:

| Thing | Where |
| --- | --- |
| Colour palette | `lib/theme/app_colors.dart` |
| Buttons, panels, frames, outlined text | `lib/widgets/game_ui.dart`, `lib/widgets/kd_button.dart` |
| Board sockets, drag ghost, block fallback | `lib/game/widgets/block_painter.dart` |
| Icon fallbacks | `lib/widgets/game_icons.dart` |
| Vector logo mark | `lib/widgets/kingdom_logo.dart` |
| Kingdom scenery (sky, hills, ground, trees) | `lib/screens/kingdom/kingdom_view.dart` |

Two decisions worth knowing about:

- **The board uses five colours, not six.** The tile sheet has a sixth block,
  but it is a red-orange within a few degrees of the red one, and two colours
  that close on a 7×7 board hurt legibility rather than adding variety. Block
  colour is decoration — the engine never matches on it — so the palette is the
  five well-separated hues. `AppColors.blocks` is sampled from them and stays
  index-aligned with `AppArt.tiles`.
- **All ten realms share the Forgotten Keep's castle art**, because that is the
  only castle in the pack. The scenery behind it is painted from each realm's
  `KingdomPalette`, so the realms do look like different places. Per-realm
  castle art is the first thing worth commissioning next; dropping it in is a
  change to `AppArt.keepFor` and nothing else.

**Regenerating the app icons** after changing `branding/app_icon.png`:

```bash
flutter run -d <any device> -t tool/generate_icons.dart
```

It resizes the painted badge into every Android mipmap bucket, every iOS
`AppIcon.appiconset` size, the Android adaptive-icon foreground, the iOS launch
images and a 1024px master at `assets/images/app_icon_1024.png`. If the painted
badge is missing it falls back to rasterising `KingdomLogoPainter`. Run it from
the project root.

**A custom font:** drop a licensed face into `assets/fonts/`, uncomment the
`fonts:` block in `pubspec.yaml`, and set `AppTextStyles.displayFontFamily`.
The app currently uses the platform UI font, which looks correct on both
Android and iOS out of the box.

### Sound

Twelve effects and a music loop, in `assets/audio/`. Like the art, they are
**generated rather than licensed**: `tool/generate_audio.py` synthesises all of
them from sine partials, filtered noise and a Karplus-Strong plucked string, so
there is no third-party audio in the project. Regenerate with:

```bash
python3 tool/generate_audio.py     # needs numpy and ffmpeg
```

The whole set is about 440 KB. `lib/audio/audio_service.dart` defines the `Sfx`
enum and maps each cue to a filename; dropping in replacement files with the
same names needs no code change. See `assets/audio/README.md` for the list and
the design notes.

The service checks the asset manifest at startup, so emptying `assets/audio/`
makes the game run silently rather than paying for players it cannot use — it
never touches the platform audio plugin at all. Individual missing files are
probed once, then muted.

Music, Sound and Haptics toggles are in Settings and in the in-game pause menu,
and persist.

---

## Enabling real ads

The game ships in **mock ad mode**: pressing "Watch Ad" resolves successfully
after a short delay, so every reward path is exercisable with no network, no
account and no SDK. Production ad unit IDs are never committed — they are
supplied at build time.

1. Create an AdMob account and register the app for both platforms.
2. Add the SDK:
   ```bash
   flutter pub add google_mobile_ads
   ```
3. Add your AdMob **app ID** to the native projects (this one is not secret and
   does have to live in the manifest/plist):
   - `android/app/src/main/AndroidManifest.xml`, inside `<application>`:
     ```xml
     <meta-data
         android:name="com.google.android.gms.ads.APPLICATION_ID"
         android:value="ca-app-pub-XXXXXXXX~YYYYYYYY"/>
     ```
   - `ios/Runner/Info.plist`:
     ```xml
     <key>GADApplicationIdentifier</key>
     <string>ca-app-pub-XXXXXXXX~YYYYYYYY</string>
     ```
4. Write an `AdService` implementation backed by `google_mobile_ads` and return
   it from `createAdService()` in `lib/monetisation/ad_service.dart`. The
   interface is four methods; the mock next to it shows the expected behaviour,
   including what each result value means.
5. Uncomment the ads keep-rules in `android/app/proguard-rules.pro`.
6. Build with the unit IDs supplied as defines:
   ```bash
   flutter build appbundle --release \
     --dart-define=ADS_ENABLED=true \
     --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/YYYY \
     --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-XXXX/YYYY
   ```

Until step 6, `AppConfig.adsEnabled` is false and the mock stays in charge. The
defaults in `AppConfig` are Google's public **test** IDs, which only ever serve
test creatives.

Interstitial pacing lives in `InterstitialPacer` — no ads for a new player's
first few games, then at most one every few games, and none at all for players
who bought Remove Ads. Rewarded ads always remain available, because the player
chooses those.

---

## Enabling real in-app purchases

The game ships in **mock purchase mode**: entitlements are granted locally with
no store involved, so the shop, the starter pack and Remove Ads are all fully
testable offline.

1. Create these product IDs in **both** Google Play Console and App Store
   Connect. They must match `lib/monetisation/products.dart` exactly:

   | Product ID | Type | Suggested price |
   | --- | --- | --- |
   | `coins_500` | Consumable | £0.99 |
   | `coins_1200` | Consumable | £1.99 |
   | `coins_3000` | Consumable | £3.99 |
   | `coins_8000` | Consumable | £7.99 |
   | `coins_25000` | Consumable | £19.99 |
   | `starter_pack` | Non-consumable | £1.99 |
   | `remove_ads` | Non-consumable | £3.99 |

2. Add the plugin:
   ```bash
   flutter pub add in_app_purchase
   ```
3. Write a `PurchaseService` implementation and return it from
   `createPurchaseService()` in `lib/monetisation/purchase_service.dart`. Grant
   entitlements by calling the shared `grantEntitlement()` helper so a real
   store gives exactly what the mock does.
4. Uncomment the billing keep-rules in `android/app/proguard-rules.pro`.
5. Build with `--dart-define=BILLING_ENABLED=true`.

The prices in `ProductCatalog` are display placeholders for mock mode only. A
real build must show the localised price string the store returns — both Apple
and Google require this.

**Restore Purchases** is already wired into Settings and is required by Apple's
review guidelines for any app selling non-consumables.

---

## Release builds

> **Not verified in this repository's build environment.** The Android SDK
> repository host is unreachable from the sandbox this project was developed in,
> and iOS builds require macOS and Xcode. The Gradle and Xcode configuration
> below is written and reviewed but the resulting binaries have not been
> produced here — run these commands locally before your first upload and treat
> the first run as a real step, not a formality. Everything else in this README
> (gameplay, tests, analysis, the desktop run) was executed and verified.

### Android App Bundle (what Google Play wants)

```bash
flutter build appbundle --release
# output: build/app/outputs/bundle/release/app-release.aab
```

An APK, for sideloading and testing:

```bash
flutter build apk --release --split-per-abi
# output: build/app/outputs/flutter-apk/
```

Signing is read from `android/key.properties`, which is gitignored. Create it:

```properties
storePassword=<your keystore password>
keyPassword=<your key password>
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Generate the keystore once and **back it up somewhere safe** — losing it means
you can never update the app under the same listing:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

If `key.properties` is absent the release build falls back to the debug key so
local testing still works, and Gradle prints a warning. A debug-signed bundle
cannot be uploaded to Google Play.

### iOS archive (what the App Store wants)

Requires macOS with Xcode installed.

```bash
flutter build ipa --release
# then open the archive in Xcode's Organizer to upload
open build/ios/archive/Runner.xcarchive
```

Or from Xcode directly:

```bash
open ios/Runner.xcworkspace
# Product > Destination > Any iOS Device
# Product > Archive
# Distribute App > App Store Connect > Upload
```

Before the first archive you must set the signing team in Xcode: select the
**Runner** target → **Signing & Capabilities** → tick *Automatically manage
signing* → choose your Apple Developer team.

### Version numbers

Both platforms take their version from `pubspec.yaml`:

```yaml
version: 1.0.0+1
#        ^^^^^ ^
#        name  build number
```

Increment the build number for **every** upload, even a re-upload of the same
marketing version. Both stores reject a duplicate.

---

## What you still need to supply

These are the things that genuinely cannot be produced from inside the project.

**Required before you can ship:**

1. **Android upload keystore** — generate it with the `keytool` command above
   and create `android/key.properties`. Back the `.jks` file up; it is
   unrecoverable.
2. **Apple Developer Program membership** (£79/$99 a year), a signing
   certificate and a provisioning profile. Setting the team in Xcode handles
   the last two automatically.
3. **A privacy policy URL** — both stores require one for an app that shows
   ads. Put it in `AppConfig.privacyPolicyUrl`.
4. **A support URL or email** — Apple requires a working support contact on the
   listing. Put it in `AppConfig.supportUrl` / `AppConfig.supportEmail`.
5. **A final application ID** — replace `com.yourcompany.kingdomdrop`
   everywhere listed [above](#application-id-and-app-name).

The Settings screen deliberately **hides** the Privacy, Terms and Support rows
until those config values are filled in. No contact details, company name or
address have been invented anywhere in this project.

**Required only for monetisation:**

6. **AdMob account and ad unit IDs** — see [Enabling real ads](#enabling-real-ads).
7. **Store product configuration** — the seven product IDs in both consoles,
   plus a completed tax and banking profile. Neither store will show products
   until banking is set up.

**Optional polish:**

8. **A licensed display font**, if you want one — see [Art](#art). The game
   uses the platform UI font, which looks correct on both Android and iOS.
9. **Castle art for realms 2–10.** The pack covers the Forgotten Keep only,
   and all ten realms currently share it. See [Art](#art).

---

## Known MVP limitations

Deliberate scope decisions, listed so nothing is a surprise:

- **No accounts, no backend, no cloud save.** Progress lives on the device.
  Reinstalling or switching phones starts over. The `StorageRepository`
  interface is the seam where a cloud save would attach.
- **No leaderboards, tournaments, season pass, friends, events or skins.**
  These were explicitly out of scope; the architecture leaves room for them.
- **English only.** No `intl` or `.arb` files yet; user-facing strings are
  inline in the widgets that show them.
- **Portrait only**, on both phone and tablet. On a tablet the game runs at
  phone proportions rather than using the extra space.
- **One daily challenge type per day**, drawn from five. Adding more means one
  enum value and one `switch` arm in `DailyService`.
- **`_openUrl` in Settings shows the URL in a snackbar** rather than opening a
  browser. The rows are hidden until real URLs exist; wiring `url_launcher` is
  a one-line change at that point.
- **Rewards are banked when the summary screen opens**, not when the player
  taps a claim button. This deviates from a literal "CLAIM" flow on purpose: an
  interruption at that moment would otherwise silently discard a whole run.
  Watching the rewarded ad then grants a second helping on top.
- **Interstitial ads are architected and paced but never shown in mock mode.**
  An invisible pause between games would make development feel broken. They
  activate with a real ad implementation.
- **The Linux desktop target is a development convenience**, not a supported
  platform.
- **Android and iOS binaries have not been built in this environment** — see
  the note under [Release builds](#release-builds).

---

## Release checklist

Work top to bottom. Everything above the line is code; everything below needs
a store console.

### Configuration

- [ ] Application ID changed from `com.yourcompany.kingdomdrop` in all three places
- [ ] `AppConfig.privacyPolicyUrl` set to a live URL
- [ ] `AppConfig.termsOfServiceUrl` set (optional but recommended)
- [ ] `AppConfig.supportUrl` or `supportEmail` set
- [ ] Display name correct on both platforms
- [ ] `version:` in `pubspec.yaml` set, build number incremented

### Build health

- [ ] `flutter analyze` reports no issues
- [ ] `flutter test` passes
- [ ] `flutter build appbundle --release` succeeds
- [ ] `flutter build ipa --release` succeeds (macOS)
- [ ] Release build installed and played on a real Android device
- [ ] Release build installed and played on a real iPhone
- [ ] Debug menu confirmed absent from the release build (no red bug button on Home)

### Monetisation

- [ ] Seven product IDs created in Google Play Console
- [ ] Seven product IDs created in App Store Connect
- [ ] Tax and banking details completed in both consoles
- [ ] A real purchase tested through a Play internal test track
- [ ] A real purchase tested through TestFlight / a sandbox Apple ID
- [ ] Restore Purchases verified on iOS
- [ ] AdMob units created and a rewarded ad verified on device
- [ ] Ad content rating set in AdMob

### Store listing

- [ ] Screenshots captured (see `STORE_LISTING.md` for the six-shot plan)
- [ ] Feature graphic created (Google Play, 1024×500)
- [ ] Descriptions and keywords filled in from `STORE_LISTING.md`
- [ ] Content rating questionnaire completed (both stores)
- [ ] Google Play Data Safety form completed
- [ ] Apple App Privacy ("nutrition label") completed
- [ ] Privacy policy URL entered in both consoles
- [ ] Category and age rating set
- [ ] Export compliance answered (this app uses no non-exempt encryption)

### Final

- [ ] Upload keystore backed up somewhere you will still have in three years
- [ ] Internal test track / TestFlight build reviewed by someone other than you
- [ ] Crash reporting considered (none is wired up in the MVP)

---

## Licence

No licence has been chosen. Add one before publishing the source.
