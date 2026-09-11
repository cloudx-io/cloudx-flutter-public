# CloudX Trusted Arbiter Demo - Flutter

A working Trusted Arbiter integration for interstitials. CloudX and AdMob load
in parallel, both fills become bids, and `CloudX.arbiter` decides which one is
shown. Companion to [docs.cloudx.io](https://docs.cloudx.io/en/flutter).

Rewarded ads follow the same flow with one extra callback, and banners are a
different (inline) flow, so neither is repeated here. Interstitial is the whole
demo.

## What Trusted Arbiter is

Your app already buys demand from somewhere else. Trusted Arbiter lets that
demand compete against CloudX on price instead of sitting in a waterfall above
or below it: you load both, hand both to CloudX as bids, and CloudX tells you
which one to show.

Two rules are easy to miss, and both are in the code:

> **The arbiter runs before the show, not during it.** Both sides load, the
> arbiter picks a winner, and the winner is stored. The tap that shows an ad
> makes no network call at all. An integration that arbitrates on the show path
> has already lost the impression to latency.

> **AdMob bids carry no price.** CloudX prices them from realized revenue you
> report back through `CloudX.reportRevenueData` after every AdMob impression.
> That call is part of the integration, not telemetry. Skip it and the AdMob
> side of every auction is priced blind.

Which is why the AdMob ids checked in here make a poor price demo: Google's test
units report a revenue of 0.0, the price store drops any revenue of 0.0, and the
AdMob bid therefore reaches the arbiter with no price at all. Expect CloudX to
lose those rounds. Point the demo at a real AdMob unit that pays to see prices
compete.

## What is in here

| File | What it is |
|---|---|
| [`lib/arbiter/arbiter_interstitial_controller.dart`](lib/arbiter/arbiter_interstitial_controller.dart) | The integration. The whole load/arbitrate/show cycle and both SDKs' calls, in one file. |
| [`lib/arbiter/arbiter_events.dart`](lib/arbiter/arbiter_events.dart) | The callbacks the controller reports through. |
| [`lib/config/demo_config.dart`](lib/config/demo_config.dart) | App key and ad unit ids, per platform. The first file to edit. |
| [`lib/tracking_gate.dart`](lib/tracking_gate.dart) | The iOS App Tracking Transparency gate. |
| [`lib/main.dart`](lib/main.dart) | The demo screen. Not part of the integration: it only makes the flow visible. |

A real integration copies the first three files and calls `load()` and `show()`.

## The cycle

```
  load()
    |
    +--> CloudX  loadInterstitial ---+
    |                                |  both settled (loaded or failed)
    +--> AdMob   InterstitialAd.load +--> CloudX.arbiter(bids) --> winner stored
                                                                        |
  show()  -----------------------------------------------------------> shows it
    |                                                            (no network call)
    +-- no winner stored? returns false; carry on with your app
                                                                        |
  ad closes --> that side's fill is consumed --> load() reloads only what is missing
```

Details worth knowing:

- **A `none` result is not a winner.** It is stored as "nothing", so the next
  `load()` runs the round again instead of parking on a winner that cannot show.
- **`load()` starts only what is missing.** After one side fails, a retry
  reloads that side alone and re-arbitrates when it settles.
- **The CloudX interstitial listener is global per ad format.** The controller
  re-claims it before every load *and* before every show, because anything else
  in your app that loads an interstitial takes it over, and its callbacks would
  go there instead.
- **The ad is destroyed from `onAdHidden`.** At that point the SDK still counts
  it as showing, and a load on it is rejected with
  `LOAD_NOT_ALLOWED_WHILE_SHOWING`. Destroying leaves the next load to build a
  fresh instance, which is also what makes it run a new auction.

## Required setup

1. **Enable Trusted Arbiter for your app in the CloudX dashboard.** No code here
   can turn it on. You can confirm it from the logs at startup:
   `[InitializationService] Arbiter enabled: https://sdk.cloudx.io/arbitration`.
2. **Match your app key to your bundle id.** Bid requests are authorized per app
   key AND bundle id. Change `lib/config/demo_config.dart`, the Android
   `applicationId` and the iOS `PRODUCT_BUNDLE_IDENTIFIER` together, or you get
   no fill and no error that says why.
3. **Set the Google Mobile Ads application id natively**, in
   `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`. The
   Google SDK throws at startup when it is absent.
4. **Answer the ATT prompt on iOS.** CloudX reads the tracking status but never
   asks for it, and treats "not determined" the same as denied. This app asks
   before initializing and refuses to continue when the answer is no.

> The ad unit ids checked in here belong to the public CloudX sample app
> (`io.cloudx.sample`), and the AdMob ids are Google's public test units.
> Replace all of them.

## Versions

| Pin | Version | Why |
|---|---|---|
| `cloudx_flutter` | 3.8.0 | The plugin. Brings the native SDKs with it. |
| `io.cloudx:sdk` | 4.7.0 | Android native SDK. Declared explicitly so the version is visible in one place. |
| `CloudXCore` | 3.8.0 | iOS native SDK. |
| `google_mobile_ads` | 9.1.0 exactly | AdMob is the second bidder. Exact, so a clone reproduces the same native graph. |
| `app_tracking_transparency` | ^2.0.4 | The ATT prompt. |

Dart 3.12 and Flutter 3.44 are the floors, set by `webview_flutter_android` and
`webview_flutter_wkwebview`, which `google_mobile_ads` 9.1.0 pulls in.

The Xcode project carries no `DEVELOPMENT_TEAM`, so signing stays on automatic
and picks your own team. Set it in Xcode before a device or archive build.

**`CloudXGoogleWaterfallAdapter` / `io.cloudx:adapter-googlewaterfall` is
deliberately absent.** It runs AdMob demand *inside* the CloudX auction, which
is the opposite of what this demo shows: here AdMob is an external bid competing
against CloudX through the arbiter. Shipping both would make the two bids the
same demand.

The adapter list in `android/app/build.gradle.kts` and `ios/Podfile` is the full
CloudX set. Take only the networks your dashboard actually serves; each one adds
to your binary.

## Running

```sh
flutter pub get
(cd ios && pod install)   # iOS only
flutter run
```

## Reading the screen

Every status line names the platform it came from, so the screen doubles as the
diagnostic.

| Line | Meaning |
|---|---|
| `CloudX` / `AdMob` | That side's last event: `loading`, `loaded: <network> $<price>`, `load failed: ...`, `showing`, `closed`. |
| `Arbiter` | `ADMOB (2 bids)`, `CLOUDX (2 bids)`, `no winner (1 bid)`, or `failed: ...`. |
| `Revenue -> CloudX` | The last AdMob paid event forwarded through `reportRevenueData`, and what that call returned. A `true` does not mean the price was kept; a revenue of 0.0 is discarded. |

If `Arbiter` only ever reads `(1 bid)`, one side is not filling. Look at which
of the two lines above it says `load failed`; the arbiter is working correctly
either way.
