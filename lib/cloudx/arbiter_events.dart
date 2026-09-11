import 'package:cloudx_flutter/cloudx.dart';

/*
 * What the controller reports back. The demo screen turns these into status
 * lines; a real integration can ignore most of them and keep only the ones it
 * acts on.
 *
 * Copy this file with arbiter_interstitial_controller.dart. Every callback
 * names the platform it came from, so one handler can serve both.
 */
class ArbiterAdEvents {
  const ArbiterAdEvents({
    required this.onAdLoaded,
    required this.onAdLoadFailed,
    required this.onArbiterCompleted,
    required this.onArbiterFailed,
    required this.onNoCandidates,
    required this.onAdShown,
    required this.onAdShowFailed,
    required this.onAdClosed,
    required this.onAdClicked,
    required this.onRevenueReported,
  });

  final void Function(CloudXArbiterPlatform platform, String detail) onAdLoaded;
  final void Function(CloudXArbiterPlatform platform, String message)
      onAdLoadFailed;

  /// Every arbiter result, with the number of bids that were submitted.
  final void Function(CloudXArbiterResult result, int bidCount)
      onArbiterCompleted;

  /*
   * The arbiter call itself failed, so no winner was selected. The loaded ads
   * are kept and the next load() runs the round again.
   */
  final void Function(String message) onArbiterFailed;

  /*
   * Both networks settled without a fill, so there is nothing to arbitrate.
   * The caller decides when to load again.
   */
  final void Function() onNoCandidates;

  final void Function(CloudXArbiterPlatform platform) onAdShown;
  final void Function(CloudXArbiterPlatform platform, String message)
      onAdShowFailed;
  final void Function(CloudXArbiterPlatform platform) onAdClosed;
  final void Function(CloudXArbiterPlatform platform) onAdClicked;

  /*
   * The AdMob paid event forwarded to CloudX, with what reportRevenueData
   * returned. Report it as the call's result, not as proof the price was kept.
   */
  final void Function(CloudXRevenueData data, bool returned) onRevenueReported;
}
