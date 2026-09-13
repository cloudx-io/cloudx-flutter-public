import 'dart:async';

import 'package:cloudx_flutter/cloudx.dart';
import 'package:flutter/material.dart';

import '../cloudx/arbiter_events.dart';
import '../cloudx/arbiter_interstitial_controller.dart';
import '../cloudx/demo_config.dart';
import '../cloudx/sdk_startup.dart';

/*
 * Demo-only UI. Ignore this file when reading the integration: every CloudX and
 * AdMob call lives under lib/cloudx/, and nothing here is meant to be copied.
 * All this screen does is turn the controller's callbacks into status lines and
 * decide when the two buttons are live.
 */
class ArbiterScreen extends StatefulWidget {
  const ArbiterScreen({super.key});

  @override
  State<ArbiterScreen> createState() => _ArbiterScreenState();
}

class _ArbiterScreenState extends State<ArbiterScreen> {
  final DemoConfig _config = DemoConfig.current;

  ArbiterInterstitialController? _controller;

  String _trackingStatus = 'requesting tracking permission';
  String _cloudXSdkStatus = 'not initialized';
  String _adMobSdkStatus = 'initializing';

  String _cloudX = 'idle';
  String _adMob = 'idle';
  String _arbiter = 'not run yet';
  String _revenue = 'no AdMob paid event yet';

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /*
   * The ordering that matters lives in SdkStartup.run, not here. This only
   * renders what it reports, and builds the controller once both SDKs are up:
   * a load issued before CloudX is initialized waits silently instead of
   * reporting a failure.
   */
  Future<void> _start() async {
    final startup = await SdkStartup.run(_config);
    if (!mounted) return;

    setState(() => _trackingStatus = startup.tracking.name);

    if (startup.trackingRefused) {
      /*
       * Both SDK rows, not just CloudX: run() returns before it starts Google
       * Mobile Ads, so leaving that row at its initial "initializing" would
       * have it waiting on an init that was never started.
       */
      setState(() {
        _cloudXSdkStatus = 'tracking not authorized - ads cannot load';
        _adMobSdkStatus = 'not started - tracking not authorized';
      });
      return;
    }

    /*
     * Null only when tracking was refused, which returned above. Checked rather
     * than asserted so a later change to that invariant cannot crash here.
     */
    final adMobReady = startup.adMobReady;
    if (adMobReady != null) {
      unawaited(
        adMobReady.then((ready) {
          if (!mounted) return;
          setState(
            () => _adMobSdkStatus = ready ? 'ready' : 'initialization failed',
          );
        }),
      );
    }

    if (!startup.cloudXInitialized) {
      /*
       * The reason comes from the SDK, not from here: initialize is the one
       * call that returns its own error code and message, and a demo that
       * printed only "failed" would hide whether the app key or the network
       * was at fault.
       */
      final failure = startup.cloudXFailure;
      setState(() => _cloudXSdkStatus = failure == null
          ? 'initialization failed'
          : 'initialization failed: $failure');
      return;
    }

    setState(() {
      _cloudXSdkStatus = 'initialized';
      _ready = true;
      _controller = ArbiterInterstitialController(
        cloudXAdUnitId: _config.interstitialAdUnitId,
        adMobAdUnitId: _config.adMobInterstitialAdUnitId,
        events: _events(),
      );
    });
  }

  ArbiterAdEvents _events() {
    return ArbiterAdEvents(
      onLoadStarted: (platform) => _set(platform, 'loading'),
      onAdLoaded: (platform, detail) => _set(platform, 'loaded: $detail'),
      onAdLoadFailed: (platform, message) =>
          _set(platform, 'load failed: $message'),
      onArbiterCompleted: (result, bidCount) => setState(() {
        _arbiter = result.platform == CloudXArbiterPlatform.none
            ? 'no winner (${_bids(bidCount)})'
            : '${result.platform} (${_bids(bidCount)})';
      }),
      onArbiterFailed: (message) =>
          setState(() => _arbiter = 'failed: $message'),
      onNoCandidates: () =>
          setState(() => _arbiter = 'no candidates - nothing to arbitrate'),
      onAdShown: (platform) => _set(platform, 'showing'),
      onAdShowFailed: (platform, message) =>
          _set(platform, 'show failed: $message'),
      onAdClosed: (platform) => _set(platform, 'closed'),
      onAdClicked: (platform) => _set(platform, 'clicked'),
      onRevenueReported: (data, returned) => setState(() {
        // What the call returned. It does not mean the price was kept.
        _revenue =
            '${data.revenue.toStringAsFixed(6)} ${data.currencyCode} '
            'reported (returned $returned)';
      }),
    );
  }

  static String _bids(int count) => count == 1 ? '1 bid' : '$count bids';

  void _set(CloudXArbiterPlatform platform, String text) {
    if (!mounted) return;
    setState(() {
      if (platform == CloudXArbiterPlatform.cloudX) {
        _cloudX = text;
      } else {
        _adMob = text;
      }
    });
  }

  void _load() {
    final controller = _controller;
    if (controller == null) return;
    /*
     * Only the arbiter row is set here. The per-platform rows are left to
     * onLoadStarted, because load() starts only the side that does not already
     * hold a fill: marking both as loading would strand the held side's row
     * there, waiting on a callback that never comes.
     */
    setState(() => _arbiter = 'waiting for both sides to settle');
    controller.load();
  }

  Future<void> _show() async {
    final controller = _controller;
    if (controller == null) return;
    final shown = await controller.show();
    if (!mounted) return;
    if (shown) {
      /*
       * Rebuild now rather than waiting for the shown callback, so the button
       * goes flat the moment the show is under way. Until it does, the stale
       * button is still live and a second tap lands on the branch below.
       */
      setState(() {});
      return;
    }
    /*
     * show() returns false for two different things, and the difference matters
     * here: a winner that went stale, or a show already in progress that a
     * second tap reached. isShowing tells them apart. Reloading on the second
     * would set the rows to "loading" while load() declines to start anything,
     * leaving the screen describing work that is not happening.
     */
    if (controller.isShowing) {
      return;
    }
    /*
     * The winner went stale between the arbiter result and the tap, so there is
     * nothing to show. A publisher would carry on with the game here; the demo
     * reloads so the next tap has something.
     */
    setState(() => _arbiter = 'winner no longer showable - reloading');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final winner = controller?.preparedWinner;
    /*
     * load() is a no-op while an ad is showing, and with a winner already
     * stored it has nothing left to load, so the button is off in both cases: a
     * tap would set the rows to "loading" with no callback coming to clear
     * them.
     */
    final canLoad = _ready &&
        controller != null &&
        !controller.isBusy &&
        !controller.isShowing &&
        winner == null;

    return Scaffold(
      appBar: AppBar(title: const Text('CloudX Trusted Arbiter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row('Tracking', _trackingStatus),
            _row('CloudX SDK', _cloudXSdkStatus),
            _row('Google Mobile Ads', _adMobSdkStatus),
            const Divider(height: 32),
            _row('CloudX', _cloudX),
            _row('AdMob', _adMob),
            _row('Arbiter', _arbiter),
            _row('Revenue -> CloudX', _revenue),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: canLoad ? _load : null,
                  child: Text(
                    (controller?.isBusy ?? false) ? 'Loading...' : 'Load both',
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: winner == null || (controller?.isShowing ?? false)
                      ? null
                      : _show,
                  child: Text(
                    winner == null ? 'Show winner' : 'Show winner ($winner)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _Explainer(),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trusted Arbiter with AdMob',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'CloudX and AdMob load in parallel; both loaded ads become bids',
            style: TextStyle(fontSize: 13),
          ),
          Text(
            'CloudX.arbiter runs once both settle; the result is stored',
            style: TextStyle(fontSize: 13),
          ),
          Text(
            'Show winner shows the stored winner - no network call here',
            style: TextStyle(fontSize: 13),
          ),
          Text(
            'AdMob paid events go to CloudX.reportRevenueData (required)',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
