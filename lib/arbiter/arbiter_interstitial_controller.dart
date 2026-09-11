import 'package:cloudx_flutter/cloudx.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'arbiter_events.dart';

/*
 * Trusted Arbiter for interstitials. CloudX and AdMob load in parallel, the
 * ones that filled become bids, and CloudX.arbiter picks the platform to show.
 *
 * This is the prepare-ahead rule from docs.cloudx.io -> Trusted Arbiter: the
 * arbiter runs as soon as both candidates have settled (loaded or failed) and
 * the result is stored; show() then shows the stored winner immediately, with
 * no arbiter call and no network call on the show path, and returns false when
 * no winner is prepared, in which case the caller carries on with the game.
 * The cycle restarts after the ad closes.
 *
 * AdMob bids carry no price. CloudX prices them from the revenue this
 * controller forwards after every AdMob impression (reportRevenueData). That
 * forwarding is a required part of the integration, not telemetry.
 *
 * This file is the whole integration. Copy it, arbiter_events.dart and your own
 * ad unit ids into your app and you have the flow.
 */
class ArbiterInterstitialController {
  ArbiterInterstitialController({
    required this.cloudXAdUnitId,
    required this.adMobAdUnitId,
    required this.events,
  });

  final String cloudXAdUnitId;
  final String adMobAdUnitId;
  final ArbiterAdEvents events;

  /// The ad format reported with AdMob revenue.
  static const String _adFormat = 'interstitial';

  /// The CloudXAd from onAdLoaded; its adValues carry the arbiter payload.
  CloudXAd? _loadedCloudXAd;
  bool _cloudXSettled = false;
  bool _isLoadingCloudX = false;

  InterstitialAd? _adMobAd;
  bool _adMobSettled = false;
  bool _isLoadingAdMob = false;

  CloudXArbiterResult? _nextWinner;
  bool _arbiterInFlight = false;

  /// A show call was made and neither close nor show-failure has arrived yet.
  bool _isShowing = false;
  bool _disposed = false;

  /// The platform show() would use right now; null when no winner is stored.
  CloudXArbiterPlatform? get preparedWinner {
    final winner = _nextWinner;
    if (winner == null || winner.platform == CloudXArbiterPlatform.none) {
      return null;
    }
    return winner.platform;
  }

  bool get isShowing => _isShowing;

  bool get isLoading => _isLoadingCloudX || _isLoadingAdMob;

  /*
   * A load or an arbiter round is in flight, so a callback is still coming.
   * load() starts only what is missing, so this reads false right after a
   * load() call that had nothing left to do: both candidates held and a winner
   * already stored.
   */
  bool get isBusy => isLoading || _arbiterInFlight;

  /*
   * Loads whichever network does not hold a fill. After one side failed, a
   * retry reloads only that side and re-arbitrates when it settles. While an ad
   * is showing nothing is loaded: the shown AdMob object must not be disposed
   * under the user, and the close callback restarts the cycle.
   */
  void load() {
    if (_disposed || _arbiterInFlight || _isShowing) {
      return;
    }

    if (_loadedCloudXAd == null && !_isLoadingCloudX) {
      _cloudXSettled = false;
      _isLoadingCloudX = true;
      /*
       * The CloudX fullscreen listeners are global per format, so the listener
       * is claimed right before every load; anything else that loads
       * interstitials owns it otherwise.
       */
      _claimCloudXListener();
      CloudX.loadInterstitial(adUnitId: cloudXAdUnitId);
    }

    if (_adMobAd == null && !_isLoadingAdMob) {
      _adMobSettled = false;
      _isLoadingAdMob = true;
      _adMobLoad();
    }

    /*
     * Both sides may already hold a fill with no winner stored, after a none
     * result or after a stale winner was dropped, in which case there is
     * nothing to load and the round has to be run again from here.
     */
    if (_nextWinner == null) {
      _maybePrepareWinner();
    }
  }

  /*
   * Shows the stored winner. A stale winner (its ad expired or was consumed) is
   * dropped and false is returned; the caller reloads. While a show is in
   * progress a second call is ignored and returns false; check isShowing to
   * tell the two apart.
   */
  Future<bool> show() async {
    final winner = _nextWinner;
    if (_disposed || _isShowing || winner == null) {
      return false;
    }
    _nextWinner = null;
    /*
     * Claim the show slot before the readiness round trip below, not after it.
     * A second tap landing inside that await would otherwise pass the guard
     * above, and a load() would re-arbitrate the fills this call is about to
     * consume and store a winner pointing at a consumed ad. Every path that
     * does not reach a show clears the flag again.
     */
    _isShowing = true;

    if (winner.platform == CloudXArbiterPlatform.cloudX) {
      final bool ready;
      try {
        ready = _loadedCloudXAd != null &&
            await CloudX.isInterstitialReady(adUnitId: cloudXAdUnitId);
      } catch (error) {
        /*
         * A platform-channel failure surfaces here as a throw. It has to be
         * caught with the slot claimed above: letting it leave would wedge the
         * controller, because load() returns early while _isShowing is set and
         * nothing would arrive to clear it. Reported as a show failure, the
         * same as one the SDK delivers through the listener.
         */
        _log('isInterstitialReady failed: $error');
        _loadedCloudXAd = null;
        _isShowing = false;
        if (!_disposed) {
          events.onAdShowFailed(CloudXArbiterPlatform.cloudX, '$error');
        }
        return false;
      }
      // The readiness check is a round trip; dispose() can land inside it.
      if (_disposed) {
        _isShowing = false;
        return false;
      }
      if (!ready) {
        _loadedCloudXAd = null;
        _isShowing = false;
        return false;
      }
      /*
       * Re-claim the global listener before showing, not only before loading:
       * anything that loaded this format in between owns it now, and its
       * display and hidden callbacks would go there instead, leaving this
       * controller stuck mid-show with no way back.
       */
      _claimCloudXListener();
      CloudX.showInterstitial(
        adUnitId: cloudXAdUnitId,
        placement: 'arbiter_interstitial',
      );
      return true;
    }

    if (winner.platform == CloudXArbiterPlatform.adMob) {
      final ad = _adMobAd;
      if (ad == null) {
        _isShowing = false;
        return false;
      }
      // Same reason as the readiness call above: a throw here would wedge it.
      try {
        await ad.show();
      } catch (error) {
        _log('AdMob show failed: $error');
        _isShowing = false;
        _disposeAdMobAd();
        if (!_disposed) {
          events.onAdShowFailed(CloudXArbiterPlatform.adMob, '$error');
        }
        return false;
      }
      return true;
    }

    _isShowing = false;
    return false;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _disposeAdMobAd();
    CloudX.destroyInterstitial(adUnitId: cloudXAdUnitId);
  }

  /*
   * Runs one arbiter round once both networks have settled and stores the
   * result. The SDK owns the timeout and the fallback and always completes: one
   * bid wins without a service call, several bids go to the arbiter service or,
   * when it is unavailable, to the local highest-price fallback. Nothing here
   * wraps the call in a timer or compares prices; the docs forbid both.
   */
  Future<void> _maybePrepareWinner() async {
    if (_disposed || _arbiterInFlight || !_cloudXSettled || !_adMobSettled) {
      return;
    }

    final bids = <CloudXArbiterBid>[];
    final cloudXAd = _loadedCloudXAd;
    if (cloudXAd != null) {
      bids.add(CloudXArbiterBid.cloudX(cloudXAd));
    }
    if (_adMobAd != null) {
      bids.add(
        CloudXArbiterBid.adMob(
          adUnitId: adMobAdUnitId,
          networkName: _adMobNetworkName,
        ),
      );
    }
    if (bids.isEmpty) {
      events.onNoCandidates();
      return;
    }

    _arbiterInFlight = true;
    _log('arbiter: ${bids.length} bid(s) for $cloudXAdUnitId');
    final CloudXArbiterResult result;
    try {
      result = await CloudX.arbiter(CloudXArbiterConfiguration(bids: bids));
    } catch (error) {
      /*
       * The arbiter itself always completes, but a platform-channel failure
       * still surfaces here as a throw, and nothing awaits this round; it would
       * escape as an unhandled async error. Report it instead. The held ads
       * stay, so the next load() runs the round again.
       */
      _log('arbiter failed: $error');
      if (!_disposed) {
        events.onArbiterFailed('$error');
      }
      return;
    } finally {
      // Cleared either way, so one failure cannot wedge every later round.
      _arbiterInFlight = false;
    }
    if (_disposed) {
      return;
    }

    _log(
      'arbiter result: platform=${result.platform} '
      'platformName=${result.platformName} id=${result.id} '
      'bidId=${result.bidId ?? '-'} bids=${bids.length}',
    );
    /*
     * A none result is not a winner. Storing it would leave load() with nothing
     * to load and no round to run: both sides still hold their fills, so
     * neither branch above starts anything and the slot never clears.
     */
    _nextWinner =
        result.platform == CloudXArbiterPlatform.none ? null : result;
    events.onArbiterCompleted(result, bids.length);
  }

  //
  // CloudX
  //

  void _claimCloudXListener() {
    CloudX.setInterstitialListener(
      CloudXInterstitialListener(
        onAdLoaded: _handleCloudXLoaded,
        onAdLoadFailed: (adUnitId, error) =>
            _handleCloudXLoadFailed(adUnitId, error.message),
        onAdDisplayed: _handleCloudXShown,
        onAdDisplayFailed: (ad, error) =>
            _handleCloudXShowFailed(ad, error.message),
        onAdHidden: _handleCloudXHidden,
        onAdClicked: _handleCloudXClicked,
      ),
    );
  }

  void _handleCloudXLoaded(CloudXAd ad) {
    if (_disposed || ad.adUnitId != cloudXAdUnitId) return;
    _isLoadingCloudX = false;
    _loadedCloudXAd = ad;
    _cloudXSettled = true;
    events.onAdLoaded(
      CloudXArbiterPlatform.cloudX,
      '${ad.networkName} \$${ad.revenue.toStringAsFixed(4)}',
    );
    _maybePrepareWinner();
  }

  void _handleCloudXLoadFailed(String adUnitId, String message) {
    if (_disposed || adUnitId != cloudXAdUnitId) return;
    _isLoadingCloudX = false;
    _loadedCloudXAd = null;
    _cloudXSettled = true;
    events.onAdLoadFailed(CloudXArbiterPlatform.cloudX, message);
    _maybePrepareWinner();
  }

  void _handleCloudXShown(CloudXAd ad) {
    if (_disposed || ad.adUnitId != cloudXAdUnitId) return;
    events.onAdShown(CloudXArbiterPlatform.cloudX);
  }

  void _handleCloudXShowFailed(CloudXAd ad, String message) {
    if (_disposed || ad.adUnitId != cloudXAdUnitId) return;
    _loadedCloudXAd = null;
    _isShowing = false;
    events.onAdShowFailed(CloudXArbiterPlatform.cloudX, message);
  }

  void _handleCloudXHidden(CloudXAd ad) {
    if (_disposed || ad.adUnitId != cloudXAdUnitId) return;
    // The fill is consumed; the next load() requests a new one.
    _loadedCloudXAd = null;
    _isShowing = false;
    /*
     * Destroy before the caller starts the next cycle, mirroring the AdMob
     * side. The ad this callback belongs to still counts as showing inside the
     * SDK at this point, and a load on it is rejected with
     * LOAD_NOT_ALLOWED_WHILE_SHOWING; destroying leaves the next load to build
     * a fresh instance, which is also what makes it run a new auction.
     */
    CloudX.destroyInterstitial(adUnitId: cloudXAdUnitId);
    events.onAdClosed(CloudXArbiterPlatform.cloudX);
  }

  void _handleCloudXClicked(CloudXAd ad) {
    if (_disposed || ad.adUnitId != cloudXAdUnitId) return;
    events.onAdClicked(CloudXArbiterPlatform.cloudX);
  }

  //
  // AdMob
  //

  void _adMobLoad() {
    InterstitialAd.load(
      adUnitId: adMobAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _adMobAd = ad;
          _registerAdMobEvents(ad);
          _isLoadingAdMob = false;
          _adMobSettled = true;
          events.onAdLoaded(CloudXArbiterPlatform.adMob, _adMobNetworkName);
          _maybePrepareWinner();
        },
        onAdFailedToLoad: (error) {
          if (_disposed) return;
          _isLoadingAdMob = false;
          _adMobSettled = true;
          events.onAdLoadFailed(CloudXArbiterPlatform.adMob, error.message);
          _maybePrepareWinner();
        },
      ),
    );
  }

  void _registerAdMobEvents(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        if (_disposed) return;
        events.onAdShown(CloudXArbiterPlatform.adMob);
      },
      onAdDismissedFullScreenContent: (_) {
        _disposeAdMobAd();
        _isShowing = false;
        if (_disposed) return;
        events.onAdClosed(CloudXArbiterPlatform.adMob);
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        _disposeAdMobAd();
        _isShowing = false;
        if (_disposed) return;
        events.onAdShowFailed(CloudXArbiterPlatform.adMob, error.message);
      },
      onAdClicked: (_) {
        if (_disposed) return;
        events.onAdClicked(CloudXArbiterPlatform.adMob);
      },
    );

    // Required: this is how CloudX learns what the AdMob bid was worth.
    ad.onPaidEvent = (paidAd, valueMicros, precision, currencyCode) {
      _reportAdMobPaidEvent(
        valueMicros: valueMicros,
        precision: precision,
        currencyCode: currencyCode,
        adSourceName: _adSourceNameOf(paidAd.responseInfo),
      );
    };
  }

  void _disposeAdMobAd() {
    _adMobAd?.dispose();
    _adMobAd = null;
  }

  /*
   * Forward Google's impression-level revenue so CloudX learns what AdMob
   * demand actually pays. google_mobile_ads reports valueMicros on both
   * platforms (it multiplies the iOS currency-unit value by 1,000,000), so the
   * division applies on both.
   */
  Future<void> _reportAdMobPaidEvent({
    required double valueMicros,
    required PrecisionType precision,
    required String currencyCode,
    required String? adSourceName,
  }) async {
    final data = CloudXRevenueData(
      platform: CloudXRevenuePlatform.adMob,
      revenue: valueMicros / 1000000.0,
      adFormat: _adFormat,
      currencyCode: currencyCode,
      precision: _toCloudXRevenuePrecision(precision),
      // An empty ad source name is not a name; report it as absent.
      networkName: adSourceName == null || adSourceName.trim().isEmpty
          ? null
          : adSourceName,
      adUnitId: adMobAdUnitId,
    );
    /*
     * Called from Google's paid-event callback, so nothing awaits this; a throw
     * would escape as an unhandled async error rather than reaching a caller.
     */
    bool returned;
    try {
      returned = await CloudX.reportRevenueData(data);
    } catch (error) {
      _log('reportRevenueData failed: $error');
      returned = false;
    }
    /*
     * What the call returned, not an acceptance: with ILRD telemetry enabled
     * the SDK returns the ILRD emission result rather than whether the price
     * reached its store, and the store drops any revenue of 0.0 - which is
     * exactly what Google's test units pay.
     */
    _log(
      'reportRevenueData($valueMicros micros $currencyCode, $precision) '
      'returned=$returned',
    );
    if (!_disposed) {
      events.onRevenueReported(data, returned);
    }
  }

  static CloudXRevenuePrecision _toCloudXRevenuePrecision(
    PrecisionType precision,
  ) {
    switch (precision) {
      case PrecisionType.precise:
        return CloudXRevenuePrecision.exact;
      case PrecisionType.estimated:
        return CloudXRevenuePrecision.estimated;
      case PrecisionType.publisherProvided:
        return CloudXRevenuePrecision.publisherDefined;
      case PrecisionType.unknown:
        return CloudXRevenuePrecision.undefined;
    }
  }

  /*
   * The ad source that filled, used as the bid's networkName. Google reports an
   * empty name for some fills (seen on an emulator), which is not a name at
   * all, so it falls back to "admob", the default the native SDK applies to a
   * blank one anyway.
   */
  String get _adMobNetworkName {
    final adSourceName = _adSourceNameOf(_adMobAd?.responseInfo);
    return adSourceName == null || adSourceName.trim().isEmpty
        ? 'admob'
        : adSourceName;
  }

  static String? _adSourceNameOf(ResponseInfo? responseInfo) =>
      responseInfo?.loadedAdapterResponseInfo?.adSourceName;

  void _log(String message) =>
      debugPrint('[CloudXArbiterDemo][interstitial] $message');
}
