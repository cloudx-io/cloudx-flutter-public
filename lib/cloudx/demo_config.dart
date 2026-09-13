import 'dart:io';

/*
 * Identifiers for the public CloudX sample app.
 *
 * Replace all of them with your own, and set your bundle identifier to match
 * the dashboard app the keys belong to: bid requests are authorized per app key
 * AND bundle id, so the SDK gets no fill when only one of the two matches.
 * These values belong to `io.cloudx.sample`, the same dashboard app the public
 * Unity and React Native demos use.
 *
 * Trusted Arbiter has to be enabled for your app in the CloudX dashboard. No
 * code in this repository can turn it on.
 *
 * The AdMob unit ids are Google's public test units, so the AdMob side of every
 * round fills without an Ad Manager account of your own.
 *
 * The AdMob APPLICATION id is not here and cannot be: Google reads it from the
 * native files before any Dart runs, so it lives in
 * android/app/src/main/AndroidManifest.xml as the
 * com.google.android.gms.ads.APPLICATION_ID meta-data and in
 * ios/Runner/Info.plist as GADApplicationIdentifier. The Google Mobile Ads SDK
 * throws at startup when it is absent. Only the per-placement AdMob unit ids
 * below are set from Dart.
 *
 * The first file to edit. Copy it, or drop it and hand your own ids to
 * ArbiterInterstitialController directly.
 */
class DemoConfig {
  const DemoConfig._({
    required this.appKey,
    required this.interstitialAdUnitId,
    required this.adMobInterstitialAdUnitId,
  });

  final String appKey;
  final String interstitialAdUnitId;
  final String adMobInterstitialAdUnitId;

  static const DemoConfig _ios = DemoConfig._(
    appKey: 'CmuKsWum6hx3yZK5SY_V_',
    interstitialAdUnitId: '9SizbPM3Dctz71WM2BKpi',
    adMobInterstitialAdUnitId: 'ca-app-pub-3940256099942544/4411468910',
  );

  static const DemoConfig _android = DemoConfig._(
    appKey: '0qE4q2MoJzoOkFQQKAtkt',
    interstitialAdUnitId: 'PwIOPhOD0KMCB_aqz8c89',
    adMobInterstitialAdUnitId: 'ca-app-pub-3940256099942544/1033173712',
  );

  static DemoConfig get current => Platform.isIOS ? _ios : _android;
}
