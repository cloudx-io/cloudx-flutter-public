import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloudx_flutter/cloudx.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'demo_config.dart';
import 'tracking_gate.dart';

/*
 * Brings both SDKs up, in the order they have to come up in.
 *
 * Copy this file with tracking_gate.dart, which it calls. The order is the
 * whole point of the file and it is not obvious from either SDK's own docs:
 * the ATT prompt has to be answered before CloudX.initialize, because CloudX
 * reads the tracking status at init and never asks for it, and treats "not
 * determined" the same as denied. Initialize first and every request that
 * session goes out without an IDFA and with dnt = 1.
 *
 * Nothing here builds UI. run() reports what happened and the caller decides
 * what to show.
 */
class SdkStartup {
  const SdkStartup._();

  /*
   * Runs the sequence once. Never throws: a refused prompt and a failed
   * initialize are both ordinary outcomes a demo has to display, not errors.
   */
  static Future<SdkStartupResult> run(DemoConfig config) async {
    CloudX.setMinLogLevel(CloudXLogLevel.verbose);

    final tracking = await TrackingGate.request();
    if (tracking != TrackingStatus.authorized) {
      return SdkStartupResult._(tracking: tracking, adMobReady: null);
    }

    /*
     * Google Mobile Ads queues loads issued before init completes, so this is
     * deliberately not awaited: it does not gate the first load. The future is
     * handed back only so the caller can report readiness.
     */
    final adMobReady = MobileAds.instance.initialize().then((status) {
      final adapters = status.adapterStatuses.keys.join(', ');
      debugPrint('[CloudXArbiterDemo] AdMob ready (adapters: $adapters)');
    });

    final configuration = await CloudX.initialize(appKey: config.appKey);
    return SdkStartupResult._(
      tracking: tracking,
      adMobReady: adMobReady,
      cloudXInitialized: configuration != null,
    );
  }
}

/// What [SdkStartup.run] managed to do, and how far it got.
class SdkStartupResult {
  const SdkStartupResult._({
    required this.tracking,
    required this.adMobReady,
    this.cloudXInitialized = false,
  });

  /// The answer to the ATT prompt. Always `authorized` off iOS.
  final TrackingStatus tracking;

  /// Whether CloudX came up. False whenever [canLoadAds] is false.
  final bool cloudXInitialized;

  /*
   * Completes when Google Mobile Ads finishes initializing, for reporting only.
   * Null when tracking was refused, because init was never started.
   */
  final Future<void>? adMobReady;

  /// Tracking was refused, so no request can carry an IDFA and nothing fills.
  bool get trackingRefused => tracking != TrackingStatus.authorized;
}
