import 'package:cloudx_flutter/cloudx.dart';

/*
 * What the controller reports back. The demo screen turns these into status
 * lines; a real integration can ignore most of them and keep only the ones it
 * acts on.
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

  /// The AdMob paid event forwarded to CloudX, and whether the SDK accepted it.
  final void Function(CloudXRevenueData data, bool accepted) onRevenueReported;
}
