# Getting your ad IDs

This guide explains, network by network, how to create the account, the app, and **every ID** that unified_ads needs:
the app-level credential and the banner / interstitial / rewarded unit IDs.

> **Verified on 2026-10-07** against each vendor's official help pages (linked under every step). Ad dashboards change
> often. Labels that the official pages did not confirm are marked ⚠, so look for the closest equivalent in your
> dashboard.

## Overview

| Network | Console | App-level credential → `NetworkConfig.appId` | Per-format IDs → `bannerAdUnitId` / `interstitialAdUnitId` / `rewardedAdUnitId` | Also put the app ID in |
|---|---|---|---|---|
| [AdMob](#admob) | [admob.google.com](https://admob.google.com) | **App ID** `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` (one per platform) | **Ad unit IDs** `ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN` | `AndroidManifest.xml` + `Info.plist` (**required**) |
| [AppLovin MAX](#applovin-max) | [dash.applovin.com](https://dash.applovin.com) | **SDK key** (account level) | **MAX ad unit IDs** (bound to your package name / bundle ID) | — |
| [Unity Ads](#unity-ads) | [cloud.unity.com](https://cloud.unity.com) | **Game ID**: one for Android, one for iOS | **Placement IDs** | — |
| [LevelPlay](#levelplay-ironsource) | [platform.ironsrc.com](https://platform.ironsrc.com) | **App Key** (one per app/platform) | **Ad unit IDs** | — |
| [InMobi](#inmobi) | [publisher.inmobi.com](https://publisher.inmobi.com) | **Account ID** | **Placement IDs** (numeric) | — |
| [Start.io](#startio) | [portal.start.io](https://portal.start.io) | **App ID** | *none*: optional free-form ad tags | — |
| [Facebook Audience Network](#facebook-audience-network) | [Monetization Manager](https://business.facebook.com/pub/start) (Meta) | *none* | **Placement IDs** (one per format) | Test device hash |

**Tips for every network**
- Create **one app per platform** (Android and iOS get different IDs). In Dart, use
  `PlatformValue.select(android: '…', ios: '…')` for any ID that differs per platform.
- Use the **exact** package name (Android `applicationId`) and bundle ID (iOS). Several networks bind ads to it.
- New apps and units can take **hours to days** to start serving (account approval, app review, propagation). While waiting,
  use test mode.
- Publish an **`app-ads.txt`** file on your developer website. It is required by AdMob for new apps, and many advertisers won't bid without it.
- **Never ship test mode or test IDs** in a production build.

---

## AdMob

**You need:** an App ID per platform, plus one ad unit ID per format.

### 1. Create the account
1. Sign in at [admob.google.com](https://admob.google.com) with a Google account. Choose your **country/territory** (it can't be
   changed later) and accept the terms. Verify a phone number (6-digit code by SMS or call). Submit payment details (name,
   individual or organization, address). If you already use AdSense, sign in with the same Google account.
   ([help](https://support.google.com/admob/answer/7356219))
2. Account verification usually takes **up to 24 hours** (rarely up to 2 weeks).

### 2. Add your app (once per platform)
1. **Apps** (sidebar) → **Add app** → choose **Android** or **iOS**.
2. *Published app:* choose "Yes, it's listed on a supported app store" → search by name or store URL → **Add**.
   *Not published yet:* choose **No** → enter the app name → **Add**. Link the store listing later.
   ([help](https://support.google.com/admob/answer/9989980))
3. Each app goes through an **app readiness review** (usually 2–3 days). It can only be reviewed once it's **published and
   linked** to a store, and serving is limited until it shows **Ready**. ([help](https://support.google.com/admob/answer/10564477))

### 3. Find the App ID
**Apps** → **View all apps** → click the copy icon in the **App ID** column. It's also on the app's **App settings** page.
([help](https://support.google.com/admob/answer/7356431))
Format: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` (note the **`~`**).

### 4. Create the ad units
1. **Apps** → *your app* → **Ad units** → **Add ad unit** (or **Get started** for the first one).
2. Click **Select** on **Banner**, **Interstitial**, or **Rewarded**, enter a name, and click **Create ad unit**.
   For **Rewarded**, set the **Reward amount** (whole number) and **Reward item** (e.g. `coins`). These become the
   `RewardItem` you receive. ([help](https://support.google.com/admob/answer/7311346), [rewarded](https://support.google.com/admob/answer/7311747))
3. The **ad unit ID** appears on the confirmation screen and later in **Ad units** → **Ad unit** column.
   Format: `ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN` (note the **`/`**).
4. New ad units usually take **a few hours** to serve. ⚠ Google gives no exact figure.

### 5. Testing, consent, app-ads.txt
- **Test devices:** **Settings** → **Test devices** → **Add test device** (advertising ID/IDFA; takes up to 24 h). Or put the
  hashed ID that the SDK prints to logcat / the Xcode console into `NetworkConfig.testDeviceIds`.
  ([help](https://support.google.com/admob/answer/9691433))
- **Google's demo ad units** always serve test ads and need no account. See [Testing without your own IDs](#testing-without-your-own-ids).
- **Consent (UMP):** **Privacy & messaging** → **Create** a **GDPR** message (select apps, languages, targeting, privacy policy
  URL → **Publish**) and, if needed, a **US state regulations** message. `AdmobConsentProvider` shows these.
  ([GDPR](https://support.google.com/admob/answer/10113207), [US states](https://support.google.com/admob/answer/10860309))
- **app-ads.txt** (required for new apps since Jan 2025): **Apps** → **View all apps** → **app-ads.txt** → **How to set up
  app-ads.txt**. Copy your line (`google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`) into
  `https://<your-domain>/app-ads.txt`, then **App settings** → **Verify app**.
  ([help](https://support.google.com/admob/answer/9363762))

### 6. Put the IDs in your app
```xml
<!-- android/app/src/main/AndroidManifest.xml, inside <application> -->
<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
           android:value="ca-app-pub-XXXXXXXXXXXXXXXX~AAAAAAAAAA"/>
```
```xml
<!-- ios/Runner/Info.plist -->
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~IIIIIIIIII</string>
```
```dart
AdNetwork.admob: NetworkConfig(
  appId: PlatformValue.select(android: 'ca-app-pub-…~AAAA', ios: 'ca-app-pub-…~IIII'),
  bannerAdUnitId: PlatformValue.select(android: 'ca-app-pub-…/1111', ios: 'ca-app-pub-…/2222'),
  interstitialAdUnitId: PlatformValue.select(android: 'ca-app-pub-…/3333', ios: 'ca-app-pub-…/4444'),
  rewardedAdUnitId: PlatformValue.select(android: 'ca-app-pub-…/5555', ios: 'ca-app-pub-…/6666'),
),
```
More: [`docs/setup/admob.md`](setup/admob.md).

---

## AppLovin MAX

**You need:** the account **SDK key**, plus one MAX ad unit ID per format and platform.

### 1. Create the account
1. Sign up at [dash.applovin.com/signup](https://dash.applovin.com/signup) and enter the code sent by email. 2-step verification
   (text message) is set during sign-up. ([help](https://support.applovin.com/en/max/max-dashboard/account/account-info/))
2. **Account approval** may be required. Use the same email as your store listing (Android: email
   account-approval@applovin.com from your Play Store developer email).
   ([help](https://growth-support.applovin.com/hc/en-us/articles/4403932494989-What-is-the-Account-Approval-Process-))
3. Set payments in **Account → Payments → Info**, and your website domain in **Account → General → Basic Info**.
   ([help](https://support.applovin.com/en/max/getting-started))

### 2. Find the SDK key
**Account → General → Keys** ([direct link](https://dash.applovin.com/o/account#keys)). Copy the **SDK Key**: it's
`NetworkConfig.appId`. (The same page lists Report / Event keys, which unified_ads doesn't need.)
([help](https://support.applovin.com/en/max/max-dashboard/account/account-info/))

### 3. Create the ad units
1. **MAX → Mediation → Manage → Ad Units** → **Create Your Ad Unit**.
2. Enter a name, choose the **platform** (Android / iOS) and **ad format**: **Banner**, **Interstitial**, **Rewarded** (or
   **MRec** for `BannerSize.mediumRectangle`).
3. Find your app by name, package name, or bundle ID. Not live yet? Click **Manually Add Your Package Name**. **The package
   name / bundle ID is case-sensitive and must match your app exactly**: the ad unit only serves to that app.
4. Save. Create one ad unit per format per platform. Copy each **Ad Unit ID** from the Ad Units list (⚠ exact column label).
   ([help](https://support.applovin.com/en/max/max-dashboard/ad-units/create-an-ad-unit))

### 4. Testing
- Put your device's GAID / IDFA in `NetworkConfig.testDeviceIds` with `testMode: true`. Logs show "Test Mode On: true".
  ([help](https://support.applovin.com/en/max/android/testing-networks/test-mode))
- The **Mediation Debugger** lists every network and lets you force test ads.
  ([help](https://support.applovin.com/en/max/android/testing-networks/mediation-debugger))
- **app-ads.txt** (strongly recommended): copy the line from **Account → General → App-ads.txt Info**.
  ([help](https://support.applovin.com/en/max/max-dashboard/account/iab-supply-chain-validation))
- ⚠ If every MAX load **times out**, the SDK key or package name is wrong: MAX doesn't report an error for an invalid
  key (observed on a device).

```dart
AdNetwork.applovin: NetworkConfig(
  appId: '<SDK key from Account → General → Keys>',
  bannerAdUnitId: PlatformValue.select(android: '<android banner unit>', ios: '<ios banner unit>'),
  interstitialAdUnitId: PlatformValue.select(android: '…', ios: '…'),
  rewardedAdUnitId: PlatformValue.select(android: '…', ios: '…'),
  testDeviceIds: ['<your GAID / IDFA>'],
),
```
More: [`docs/setup/applovin.md`](setup/applovin.md).

---

## Unity Ads

**You need:** a **Game ID** per platform, plus a **placement ID** per format.

> Use Unity Ads **directly** only if you don't use LevelPlay. With LevelPlay, enable Unity Ads as a bidder inside LevelPlay
> instead (see [LevelPlay](#levelplay-ironsource)).

### 1. Create the project
1. Sign in at [cloud.unity.com](https://cloud.unity.com) → **Home → Projects → Create project**. Enter a name and the
   **COPPA** designation (it can't be changed later), then select **Create**. ([help](https://docs.unity.com/en-us/cloud/projects/create-project))
2. Open **Monetization** (cloud.unity.com/monetization) for the project and enable Unity Ads.
   ([help](https://docs.unity.com/en-us/grow/ads/create-unity-projects))
3. In **project Settings**, add your **Google Play Store ID** / **Apple App Store ID** (new apps can take 5–7 days to be found).
   ([help](https://docs.unity.com/en-us/grow/dashboard/get-started/project/settings))

### 2. Find the Game IDs
Open **project Settings → Game IDs**. There are two read-only IDs, **one for Android and one for iOS**.
([help](https://docs.unity.com/en-us/grow/dashboard/get-started/project/settings)) ⚠ Some Unity pages show them under
**Monetization → Placements** instead.

### 3. Placements
1. Every project starts with **six default bidding placements** (banner, interstitial and rewarded for each platform).
   ([help](https://docs.unity.com/en-us/grow/dashboard/ad-units/create)) ⚠ Their names are usually `Banner_Android`,
   `Interstitial_Android`, `Rewarded_Android` (and `_iOS`). Check your Placements list.
2. To add more: **Placements → Add placement** → name, **platform**, **ad format** (Banner / Interstitial / Rewarded),
   setup type **Bidding** → **Add Placement**. The **placement ID** comes from the original name and can't be changed.
3. **Since 11 Aug 2026, new placements are bidding only.** Waterfall placements had to be migrated or archived.
   ([help](https://docs.unity.com/en-us/grow/dashboard/ad-units))

### 4. Testing
- `testMode: true` makes the adapter initialize Unity with test mode.
- Or use the dashboard: **Monetization → Settings → Test devices** → select the app → edit **Test mode** → **Override client test
  mode** → **Force test mode ON**. You can also register devices there.
  ([help](https://docs.unity.com/en-us/ads-unity/latest/sdk-integration/test-integration))

```dart
AdNetwork.unity: NetworkConfig(
  appId: PlatformValue.select(android: '<Android Game ID>', ios: '<iOS Game ID>'),
  bannerAdUnitId: PlatformValue.select(android: 'Banner_Android', ios: 'Banner_iOS'),
  interstitialAdUnitId: PlatformValue.select(android: 'Interstitial_Android', ios: 'Interstitial_iOS'),
  rewardedAdUnitId: PlatformValue.select(android: 'Rewarded_Android', ios: 'Rewarded_iOS'),
  extras: {'rewardAmount': 10, 'rewardType': 'coins'},   // Unity rewards carry no amount
),
```
More: [`docs/setup/unity.md`](setup/unity.md).

---

## LevelPlay (ironSource)

**You need:** an **App Key** per app/platform, plus an **ad unit ID** per format, **and at least one demand network enabled**.

> **ironSource Ads direct demand was sunset on 30 April 2026** (no new publishers from 15 April, and the dashboard became
> read-only). LevelPlay mediation continues, but fill now comes from the **networks you enable in LevelPlay**. Unity
> recommends Unity Ads bidding. ([announcement](https://unity.com/products/ironsource-ads-sunset)) An app with no networks
> enabled gets **no fill**.

### 1. Create the account
Sign up at [platform.ironsrc.com/partners/signup](https://platform.ironsrc.com/partners/signup). The account stays **pending
approval** until you answer the verification emails. ([help](https://docs.unity.com/en-us/grow/levelplay/platform/get-started/create-account))

### 2. Add the app and find the App Key
1. On the dashboard, select **New App** (top right; ⚠ some pages say **Add App**).
2. *Live app:* paste the App Store / Google Play URL → **Import App Info**. *Not live yet:* enter a temporary name (update it
   later on the **Apps** page). Set **COPPA** / **CCPA** and choose the ad formats.
   ([help](https://docs.unity.com/en-us/grow/levelplay/platform/get-started/add-app))
3. The **App Key** is shown on the **Apps** page. ([help](https://docs.unity.com/en-us/grow/levelplay/sdk/unity/migrate-from-unity-ads-to-levelplay))

### 3. Create the ad units
**Ad units** page → **Create ad unit** → unique name → format (**Banner**, **Interstitial**, **Rewarded**) → **Save**. The
**Ad unit ID** is shown in the table. ([help](https://docs.unity.com/en-us/grow/levelplay/platform/get-started/ad-units))

### 4. Enable demand (required for fill)
1. **Mediation → Setup → SDK Networks** → choose a network, e.g. **Unity Ads** → enter its **API Key** and **Organization core
   ID** (from the Unity dashboard; auto-setup also needs a service-account Key ID / Secret).
2. For each app, open the network's row → **Add bidder** (auto-creates the Unity placements), or enter the Game ID and
   **bidding** placement ID by hand. ([help](https://docs.unity.com/en-us/grow/levelplay/sdk/android/networks/guides/unity-ads))
3. Other networks: **Instances** → app → network → **Add instance** → set it **Active**.
   ([help](https://docs.unity.com/en-us/grow/levelplay/platform/get-started/instances))

> The native SDK of every network you enable here must also be in your app (LevelPlay adapters). unified_ads ships only
> the LevelPlay core SDK. Adding LevelPlay network adapters is your app's Gradle / Podfile job.

### 5. Testing
- **LevelPlay → Settings → Test devices** → **Add test device** (name, advertising ID, platform) → pick a network and ad units →
  **Test ads**. ([help](https://docs.unity.com/en-us/grow/levelplay/sdk/unity/integration-testing))
- The **integration test suite** is enabled in code (`is_test_suite` meta-data), not in the dashboard.

```dart
AdNetwork.ironsource: NetworkConfig(
  appId: PlatformValue.select(android: '<Android App Key>', ios: '<iOS App Key>'),
  bannerAdUnitId: PlatformValue.select(android: '…', ios: '…'),
  interstitialAdUnitId: PlatformValue.select(android: '…', ios: '…'),
  rewardedAdUnitId: PlatformValue.select(android: '…', ios: '…'),
),
```
Don't enable `AdNetwork.unity` in the same app (see [`docs/setup/ironsource.md`](setup/ironsource.md)).

---

## InMobi

**You need:** the **Account ID**, plus a numeric **placement ID** per format.

### 1. Create the account
1. Sign up at the InMobi publisher dashboard → **Create Account** → verify your email → set a password.
   ([help](https://support.inmobi.com/monetize/getting-started))
2. A new account is in status **New**. To reach **Pending Approval**, add an app (or website) and a payment method (**Finance →
   Payment Settings**). App approval usually takes **24 working hours**.
   ([help](https://support.inmobi.com/monetize/cat-faqs/app-approval-process))

### 2. Find the Account ID
It's shown in the **top-left corner, under your account name**. ([help](https://support.inmobi.com/monetize/integrating-inmobi-with-mediation))

### 3. Add the app
**Inventory → Inventory Settings → Add Inventory** → **Mobile App** (store URL) or **Unpublished App** (**Link Manually**) →
complete the privacy declarations → **Save and Create Placements**.
([help](https://support.inmobi.com/monetize/publisher-dashboard/inventory-tab/inventory-settings))

### 4. Create the placements
1. Find the app → expand it → **+ Add a placement** → choose the ad unit type → **Create Placement(s)**.
2. Use these types:

   | unified_ads format | InMobi ad unit type |
   |---|---|
   | Banner | **Banner** (320×50, 300×250 for MREC, 728×90 for tablets) |
   | Interstitial | **Interstitial** |
   | Rewarded | **Rewarded Video**, with a reward key/value (e.g. `Coins` = `1000`, integer) |

3. The **Placement ID** (a long number) is shown under the placement name.
   ([help](https://support.inmobi.com/monetize/integrating-inmobi-with-mediation))

### 5. Testing
- InMobi has **no code-level test flag**. Turn on test mode **per placement**: **Global** (all devices) or **Device** (registered
  devices only). Register devices under the **Integration** tab → **Integration Testing** → **Add Test Device**.
  ([help](https://support.inmobi.com/monetize/android-guidelines/android-testing-and-troubleshooting))
- With `testMode: true`, the adapter sets InMobi logging to DEBUG so your advertising ID is printed in logcat.
- **Turn test mode off before release**, or the app won't earn.

```dart
AdNetwork.inmobi: NetworkConfig(
  appId: '<Account ID>',
  bannerAdUnitId: PlatformValue.select(android: '<numeric id>', ios: '<numeric id>'),
  interstitialAdUnitId: PlatformValue.select(android: '…', ios: '…'),
  rewardedAdUnitId: PlatformValue.select(android: '…', ios: '…'),   // a Rewarded Video placement
),
```
More: [`docs/setup/inmobi.md`](setup/inmobi.md).

---

## Start.io

**You need:** only the **App ID**. Start.io has no per-format ad units.

### 1. Create the account
Register at the Start.io publisher portal (email, or Google / GitHub). ([help](https://support.start.io/hc/en-us/articles/202766673-Opening-a-Publisher-Account))

### 2. Add the app and find the App ID
1. Click **Add New App** (right side of the Analytics dashboard).
2. *Published:* paste the store link into **App URL** → **Add App**. *Not published:* **Haven't published your app yet?** →
   name + platform → **Add App**.
3. The **App ID** is shown right away (click to copy) and listed under **My Apps**.
   ([help](https://support.start.io/hc/en-us/articles/202766743-Adding-a-New-App))

### 3. Ad tags (optional)
There are no ad unit IDs. A value you put in `interstitialAdUnitId` / `rewardedAdUnitId` / `bannerAdUnitId` is sent as a
free-form **ad tag** (English letters, ≤ 200 characters), which appears in the portal reports.
([help](https://support.start.io/hc/en-us/articles/360006662474-Advanced-Usage))

### 4. Testing and payment
- `testMode: true` enables Start.io test ads. **Disable it in production**, or the app won't monetize.
  ([help](https://support.start.io/hc/en-us/articles/4401980822930-Test-Your-Android-Integration))
- The minimum payout is $50. ([help](https://support.start.io/hc/en-us/articles/115005069873-Are-You-Eligible-For-a-Payment))

```dart
AdNetwork.startapp: NetworkConfig(
  appId: PlatformValue.select(android: '<Android App ID>', ios: '<iOS App ID>'),
  interstitialAdUnitId: 'levelend',   // optional ad tag (letters only)
  extras: {'rewardAmount': 1, 'rewardType': 'reward'},   // Start.io rewards carry no amount
),
```
More: [`docs/setup/startapp.md`](setup/startapp.md).

---

## Facebook Audience Network

Facebook Audience Network (branded **Meta Audience Network** since 2022) is `unified_ads_facebook`.

| unified_ads field | Facebook value | Where |
|---|---|---|
| `appId` | not needed | leave empty |
| `bannerAdUnitId` / `interstitialAdUnitId` / `rewardedAdUnitId` | **Placement ID** (`<number>_<number>`) of a placement with the matching display format | Monetization Manager → Placements |
| `testDeviceIds` | hashed device ID | logcat / Xcode console line `Test mode device hash: …` on the first request |

1. Sign in to [Monetization Manager](https://business.facebook.com/pub/start) with a Facebook account → **Create Property**
   (Business Manager required) → add the **Android** and/or **iOS** platform (package name / App Store link).
2. **Create placement** for each format: choose the display format (**Banner**, **Interstitial**, **Rewarded video**). The
   **Placement ID** is in the Placements table. ([help](https://www.facebook.com/business/help/674519316218980))
   A placement only serves its own format; using a banner placement for rewarded fails with 1011/1203 → `invalidConfig`.
3. **Testing:** prefix the placement ID with `IMG_16_9_APP_INSTALL#` (for example `IMG_16_9_APP_INSTALL#123_456`) to get a test
   creative, or add your device hash to `testDeviceIds` with `testMode: true`. Drop the prefix in release builds.
4. **Production:** Audience Network is **bidding-only**, so direct requests from this adapter are not expected to fill. For revenue,
   add Audience Network as a **bidding** network in **AdMob, MAX or LevelPlay** with the same property/placement IDs, plus
   that platform's Facebook/Meta adapter. Those ads are then served by `admob` / `applovin` / `ironsource`.

Android also needs cleartext allowed for `127.0.0.1`, and iOS needs a deployment target of 15. See
[`docs/setup/facebook.md`](setup/facebook.md).

---

## Testing without your own IDs

| Network | Public test credentials | Result on a real Android device (2026-10-07) |
|---|---|---|
| AdMob | Google demo App ID `ca-app-pub-3940256099942544~3347511713` (Android) / `~1458002511` (iOS) and the demo ad units on [Android](https://developers.google.com/admob/android/test-ads) / [iOS](https://developers.google.com/admob/ios/test-ads) | ✅ all formats serve test ads |
| Start.io | demo App ID `205489527` (from the official [android-sdk-demo](https://github.com/StartApp-SDK/android-sdk-demo)) | ✅ all formats serve |
| Unity Ads | sample Game ID `14851`, placements `bannerads`, `rewardedVideo` (from Unity's [sample app](https://github.com/Unity-Technologies/unity-ads-android)) | ✅ banner + rewarded; the sample has no interstitial placement |
| LevelPlay | official demo app key `25b63cf85` + demo ad units ([Mediation-Demo-Apps](https://github.com/ironsource-mobile/Mediation-Demo-Apps)) | ⛔ initializes, but **no fill** (demo key bound to the demo app) |
| InMobi | documented test placements, e.g. Android banner `1467162141987`, interstitial `1469137441636` ([help](https://support.inmobi.com/monetize/integrating-inmobi-with-mediation)); they need the matching test account ID | ⚠ not tried. The [sample-code](https://github.com/InMobi/sdk-sample-code-android) account + placements we did try initialized but returned NO_FILL |
| Facebook Audience Network | test placements from the example app of the [`facebook_audience_network`](https://pub.dev/packages/facebook_audience_network) plugin: banner `IMG_16_9_APP_INSTALL#2312433698835503_2964944860251047`, interstitial `IMG_16_9_APP_INSTALL#2312433698835503_2650502525028617` | ✅ banner + interstitial serve test ads; no public **rewarded** placement (a non-rewarded one fails with 1203) |
| AppLovin MAX | none public | needs your SDK key + ad units |

Use these **only for development**, and only in the example or a test build. The `example/` app's
`integration_test/network_smoke_test.dart` runs any of them with `--dart-define`, so nothing is written to your code.
