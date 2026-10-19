# Moonlight Lofi

The official iOS app for the lofi channel [@moonlight-lofii](https://www.youtube.com/@moonlight-lofii). It plays the creator's own tracks, keeps a date-based focus timer, and sells Moonlight Pro with StoreKit 2. There is no account and no backend. Purchases, stats, and downloads stay on the device.

Swift 5.9, SwiftUI, iOS 17 and later.

## Features

- Player for eleven original seamless loops, with shuffle, loop, lock screen controls, and background audio. Loop one repeats the current track through `AVPlayerLooper`, so the join stays gapless.
- Offline copies in Application Support (`MoonlightTracks`). Downloads are part of Pro.
- Focus timer with custom focus, short break, and long break lengths. Remaining time is `endDate - now`, so leaving the app does not drift the clock.
- A local notification when a phase ends, a Live Activity (Lock Screen and Dynamic Island), and a Home Screen widget.
- Sleep timer that eases the player's volume to silence, then stops. A dark screen hides the UI. While it runs, the player suggests the Luna Sleep scene.
- Eight scenes. Luna Study, Luna Sleep, and Luna Rooftop are illustrations of the mascot. Moon Garden, Rain Window, City Window, Aurora, and Starlit Shore are drawn in SwiftUI. Luna Study is the default. Luna Study and Moon Garden are free. The other six are Pro.
- Pro unlocks the full catalog, downloads, every scene, and focus stats. Free keeps the tracks marked `isPro: false`, Luna Study, and Moon Garden. The timer itself is free.
- Focus minutes and the day streak are stored with SwiftData.
- English and German, following the system language.

## Architecture

```text
Packages/MoonlightCore     Pure Foundation logic and the unit tests
MoonlightLofi              SwiftUI app: audio, StoreKit, SwiftData, scenes
Shared                     Colors, strings, widget snapshot, Live Activity attributes
MoonlightLofiWidget        Home Screen widget and Live Activity
```

`MoonlightCore` does not import UIKit, StoreKit, or SwiftData, so `swift test` covers it on a Mac or a Linux CI runner.

| Piece | Responsibility |
| --- | --- |
| `FocusTimerEngine` | Start, pause, resume, and complete phases from dates. One in-flight interval is settled when the app returns. Missed breaks are not replayed. If auto-continue is on and the app notices the end within 15 seconds, the next phase starts. |
| `SleepPlan` | Volume from the clock. Full volume until the fade window, then a cosine ease to silence. |
| `IllustratedMotion` | Aspect-fill crop around Luna. A slow Ken Burns pan on a portrait iPhone. Reduce Motion, and every other size, stays still. |
| `SleepSceneOffer` | Offers Luna Sleep while a sleep timer is running, until the listener switches or dismisses it. |
| `EntitlementPolicy` | What Free and Pro may play, download, and open. StoreKit only answers "which product ids are active?" |
| `CatalogDecoder` | `tracks.json`: safe ids, https URLs, bundled file or remote URL. |
| `PlaybackController` | `AVQueuePlayer` and `AVPlayerLooper` for gapless repeat, Now Playing, remote commands, and the sleep fade while audio is playing. |
| `DownloadManager` | Copies a bundled file, or downloads an https URL, into Application Support. |
| `StoreManager` | Loads products, purchases, restores with `AppStore.sync()`, and listens to `Transaction.updates`. |
| `FocusSessionRecord` | SwiftData row for a finished focus interval. The streak treats today, or yesterday if today is still empty, as the live end of the run. |
| Widget | Reads a `WidgetSnapshot` from the App Group. The countdown is `Text(timerInterval:)`, not a one-second timeline. |

Free sessions are still saved. The stats screen and the widget's streak stay behind Pro until a purchase or restore, then the minutes already on the device show up.

## Project layout

XcodeGen is the source of the Xcode project. `project.yml` describes the app, the widget extension, the test bundle, and the shared scheme. The scheme points at `MoonlightLofi/Resources/Products.storekit`.

```bash
brew install xcodegen
xcodegen generate
open MoonlightLofi.xcodeproj
```

## Build and sign

1. Install Xcode 15 or newer so the iOS 17 SDK is available.
2. Generate the project with the commands above.
3. Select the `MoonlightLofi` scheme. Signing & Capabilities on **both** the app and the widget need your Team.
4. Create an App Group with id `group.com.moonlightlofi.shared` and attach it to both App IDs. The entitlements files already request it. If you change the id, update both entitlements files and `AppGroupID.suite` in `Packages/MoonlightCore`.
5. Register the bundle ids before you ship:
   - App: `com.moonlightlofi.app`
   - Widget: `com.moonlightlofi.app.widget`
6. Run on an iPhone simulator (Dynamic Island needs a 14 Pro or later) or a device.

Background audio uses the `audio` background mode. Live Activities use the widget extension and `NSSupportsLiveActivities`. Neither needs a server.

Search the repo for `com.moonlightlofi` if these ids should change before you create the App Store records. The widget bundle id has to stay prefixed by the app bundle id.

## Tracks

The app ships eleven original loops by Moonlight Lofi. They are AAC, 256 kbps, 44.1 kHz, 150 seconds, normalized to −14 LUFS, and written so the end joins the start. Free tracks are Rainy Window, Midnight Tea, Notebook Margins, and Sleepy Cat Nap. The other seven are Pro. A fresh install uses Loop one, which repeats the current file with `AVPlayerLooper` instead of seeking back to zero.

Ownership is recorded in `tools/lofi-gen/MUSIC_LICENSE.md`. The generator (`lofi_gen.py`, `make_track.sh`, `batch.txt`) synthesizes the music from oscillators and noise. It does not use samples.

To add another track:

1. Render an `.m4a` with `tools/lofi-gen/make_track.sh`, or export your own master.
2. Put the file in `MoonlightLofi/Resources/Audio/` and add an object to `tracks.json`:

```json
{
  "id": "paper-lanterns",
  "title": "Paper Lanterns",
  "artist": "Moonlight Lofi",
  "mood": "mood.softKeys",
  "key": "D",
  "bpm": 80,
  "duration": 150,
  "bundledFile": "paper-lanterns.m4a",
  "isPro": true,
  "seamless": true
}
```

3. `id` is lowercase letters, digits, and hyphens. It becomes the filename in Application Support, so keep it unique.
4. `mood` and `key.*` are localization keys in `Shared/Resources`. Add a key if you need a new mood or spelling.
5. `duration` is seconds. The player replaces it with the asset duration once the file loads. `scripts/validate_catalog.py` checks it against the file within half a second.
6. `isPro: false` puts the track on the free plan. `seamless: true` is what turns Loop one into a gapless repeat.
7. Rebuild. Bundled files play without a download. Pro users can still copy them offline from the download button.

To stream instead of bundling, omit `bundledFile` and set an https URL. Do not mark the row `placeholder`; the catalog check rejects those rows.

## Scenes

Luna Study, Luna Sleep, and Luna Rooftop are landscape paintings in the asset catalog:

| Scene | Image set | Plan |
| --- | --- | --- |
| Luna Study | `luna_focus` | Free, and the default |
| Luna Sleep | `luna_sleep` | Pro. Suggested while a sleep timer is running |
| Luna Rooftop | `luna_rooftop` | Pro |

On a portrait iPhone the painting aspect-fills around Luna, who sits center-right, and drifts in a slow Ken Burns pan (`IllustratedMotion`, about 46 seconds). Reduce Motion holds the still crop, and so do iPad and landscape layouts. Stars and a little rain from the drawn scenes sit on top at low opacity, with a bottom gradient so the player stays readable. Dismissing the sleep suggestion lasts until that timer ends. Moon Garden stays free so an earlier install does not lose the scene it already had.

Replace a painting by dropping a new landscape JPG into `MoonlightLofi/Resources/Assets.xcassets/<name>.imageset/` and keeping the name in `Contents.json`. If the aspect ratio changes, update `AmbientScene.artworkAspect` so the crop still covers the screen.

## App Store Connect products

Create these in App Store Connect with the same product ids. Prices are the intended US prices; the app displays whatever StoreKit returns.

| Product id | Type | Duration | Reference price |
| --- | --- | --- | --- |
| `com.moonlightlofi.pro.monthly` | Auto-renewable subscription | 1 month | 2.99 USD |
| `com.moonlightlofi.pro.yearly` | Auto-renewable subscription | 1 year | 19.99 USD |
| `com.moonlightlofi.pro.lifetime` | Non-consumable | — | 29.99 USD |

Put the monthly and yearly products in one subscription group named **Moonlight Pro**. Yearly is the highlighted plan in the paywall.

Local testing uses `MoonlightLofi/Resources/Products.storekit`, already selected on the `MoonlightLofi` scheme. In the simulator you can buy from the paywall without an Apple ID. Restore calls `AppStore.sync()`. Terms and privacy open placeholder pages (`https://moonlightlofi.app/terms` and `https://moonlightlofi.app/privacy`); replace those URLs in `Links` before release.

## Localization

Strings live in `Shared/Resources/en.lproj` and `de.lproj`. List that folder under each target's `sources` in `project.yml`. XcodeGen has no `resources` key — an unknown key is ignored, and the strings, `tracks.json`, `Audio`, and `Assets.xcassets` never reach the app. As a group (not a folder reference), the `.lproj` directories become variant groups, which is what `NSLocalizedString` looks up. The system language picks the table. If a screen shows raw keys such as `tab.listen`, the variant group is missing from that target's Copy Bundle Resources. Add a language by copying `en.lproj`, translating, and listing the code in `project.yml` (`knownRegions`) and `CFBundleLocalizations`.

## Tests

Timer, sleep fade, entitlements, the Luna crop and sleep-scene suggestion, scene-title line breaks, catalog decoding, queue order, streaks, and English/German key parity:

```bash
swift test --package-path Packages/MoonlightCore
python3 scripts/validate_catalog.py
```

After `xcodegen generate`, those tests also run as the `MoonlightLofiTests` bundle, plus `BundleResourceTests`, which checks that the hosted app bundle contains 11 tracks, each audio file, a translated `library.header`, and the Luna scene images:

```bash
xcodebuild test \
  -project MoonlightLofi.xcodeproj \
  -scheme MoonlightLofi \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:MoonlightLofiTests
```

`.github/workflows/ios-ci.yml` is the CI run. On `macos-15` it selects the newest Xcode, checks the catalog, runs `swift test`, generates the project, and runs unit and UI tests on an available iPhone simulator (an exact iPhone 16 when that device exists). The UI tests keep screenshots of the player, scenes, library, focus timer, sleep timer, and paywall. The paywall reads `Products.storekit` from the scheme test action. Screenshots are uploaded as the `screenshots` artifact, and the result bundle as `xcresult`.

## Capabilities to confirm in Xcode

- Signing team on the app and the widget
- App Group `group.com.moonlightlofi.shared` on both
- Background Modes → Audio, AirPlay, and Picture in Picture (the plist already includes `audio`)
- In-App Purchase (StoreKit does not need an extra entitlement for these products)
