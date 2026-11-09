# unified_ads example

This app tests every ad network supported by `unified_ads` from one screen. It initializes all enabled networks. Each
network gets its own card with buttons that load and show its **banner**, **interstitial** and **rewarded** ads right there.
A **Settings** tab lets you enter your own IDs, and a live **Log** tab shows every callback.

It ships with **placeholder credentials** for most networks, so it compiles and runs out of the box. Replace every `YOUR_*` value in `lib/src/test_credentials.dart` with your own IDs before release. Test IDs live only in this example (`lib/src/test_credentials.dart`), never in the packages.

## Run it

```sh
cd example
flutter run            # Android device or emulator (a real device is recommended for ads)
```

iOS: `flutter run` on a Mac with Xcode 26.2+. The deployment target is **iOS 15**, because the Facebook adapter needs it.

## The three tabs

### Ads

- **Status header:**
  - "Initialized: N network(s) ready" and a **Re-initialize** button.
  - One chip per network: ✅ ready · ❗ init failed · ⊖ disabled or skipped · ⏳ initializing.
  - The **Banner size** selector: adaptive, standard 320×50, large 320×100, or medium rectangle 300×250. It applies to the
    next banner you open.
- **Waterfall (auto) card:** these ads walk the waterfall (the order from Settings). The first network that fills serves
  the ad, and the card shows *"served by …"*.
- **One card per network** (AdMob, Facebook Audience Network, Unity Ads, Start.io, InMobi, AppLovin MAX, LevelPlay). Each
  card **forces** that network:

  | Button | What happens |
  |---|---|
  | **Banner** / **Hide banner** | Loads that network's banner and shows it **inside the card**, or removes it |
  | **Load interstitial** → **Show interstitial** | Loads, then presents the full-screen ad |
  | **Load rewarded** → **Show rewarded** | Same; the card shows *"reward earned: amount type"* |

  Under the buttons, a status line per format shows `loading…`, `ready (served by X)`, `showing`, `closed`, or the error
  as `code [native code]`, for example `noFill [NO_FILL]`. Buttons are disabled while a network isn't ready, and the
  reason is shown (disabled, invalid config, init failed).

### Settings

- **Test mode (all networks):** forces test ads wherever the network supports it.
- **Waterfall order:** drag the handles to reorder.
- **Networks:** expand a network to:
  - enable or disable it (checkbox);
  - set its test mode (Global / On / Off);
  - enter the **App ID** (Game ID, SDK key, App key or Account ID, depending on the network), the **banner /
    interstitial / rewarded** IDs, and **test device IDs**.
- **Save & re-initialize:** saves the config (`shared_preferences`, in the same JSON schema as `ads_config.json`) and
  re-runs `UnifiedAds.init`.
- **Reset to public test IDs:** restores the built-in test credentials.

Where to find every ID: [doc/getting_ids.md](../doc/getting_ids.md).

### Log

Every `UnifiedAds.events` callback (loaded, failedToLoad, shown, failedToShow, impression, clicked, closed,
earnedReward, bannerSized) appears with a millisecond timestamp, network and format. The app's own steps (ATT, consent,
init result, load/show results) appear too. You can filter by network or **Errors only**, and **Clear** the log. The tab
badge counts the entries.

## Built-in test credentials

| Network | Enabled by default | What you get |
|---|---|---|
| AdMob | ✅ | Placeholder IDs (`YOUR_ADMOB_*`). Replace with your own AdMob App ID and ad unit IDs in Settings; Google's public demo units (`ca-app-pub-3940256099942544~…`) serve test ads but must not be copied into production. |
| Facebook Audience Network | ✅ | Placeholder placement IDs (`YOUR_FACEBOOK_*`). Replace with your own Meta placement IDs. |
| Unity Ads | ✅ | Placeholder Game ID and placement IDs (`YOUR_UNITY_*`). Replace with your own from cloud.unity.com. |
| Start.io | ✅ | Placeholder App ID (`YOUR_STARTIO_APP_ID`). Replace with your own from portal.start.io. |
| InMobi | ✅ | Placeholder Account ID and placement IDs (`YOUR_INMOBI_*`). Replace with your own from publisher.inmobi.com. |
| LevelPlay | ❌ | Placeholder App Key (`YOUR_LEVELPLAY_APP_KEY`). Off because **LevelPlay and Unity Ads can't run together**: enabling both makes unified_ads skip Unity (`configConflict`). |
| AppLovin MAX | ❌ | No placeholder key; enter your SDK key and ad units in Settings, then enable. |

All presets are **placeholders**. On any platform, networks show `invalidConfig` until you enter real IDs in Settings (AdMob has demo IDs for both platforms, but those are Google's public test units — see the note below).

## Using your own IDs

1. Open **Settings**, expand the network and paste your IDs ([how to get them](../doc/getting_ids.md)).
2. Keep **Test mode** on while developing. For networks that only do test mode through the dashboard or test devices
   (InMobi, LevelPlay, Facebook), add your device to **Test device IDs** or enable test mode in their dashboard.
3. Tap **Save & re-initialize**, then use that network's card.

Notes:
- **AdMob App ID** is also read from `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`. Change it
  there too and rebuild.
- Some SDKs accept their App ID **once per process**. If a changed App ID doesn't take effect, restart the app.
- **Facebook Audience Network** on Android needs cleartext for `127.0.0.1` (already set up in
  `android/app/src/main/res/xml/network_security_config.xml`). Audience Network is bidding-only: expect test ads only
  ([details](../doc/setup/facebook.md)).

## Code map

| File | Purpose |
|---|---|
| `lib/main.dart` | `DemoApp` → `HomeShell` with the Ads / Settings / Log tabs |
| `lib/src/ads_controller.dart` | ATT → consent (UMP) → `UnifiedAds.init`; per-network status; save & re-init |
| `lib/src/ads_screen.dart` | Status header, waterfall card, and `AdTestCard` per network (`forceNetwork`) |
| `lib/src/settings_screen.dart` | Config editor |
| `lib/src/settings_store.dart` | `shared_preferences` persistence via `AdConfigLoader` JSON |
| `lib/src/event_log.dart`, `lib/src/log_screen.dart` | Event console |
| `lib/src/test_credentials.dart` | Public test IDs (example only) |

## Tests

```sh
flutter test                                                        # widget + settings tests
flutter test integration_test/example_app_test.dart -d <device>     # drives the real UI on a device
flutter test integration_test/plugin_integration_test.dart -d <device>
flutter test integration_test/network_smoke_test.dart -d <device> --dart-define=NETWORK=<id> --dart-define=APP_ID=<…> …
```

`example_app_test.dart` taps **Banner** and **Load interstitial** in the Facebook, Unity, Start.io, InMobi and AdMob cards,
shows the AdMob interstitial, and prints a per-network summary.
