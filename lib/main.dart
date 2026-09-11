import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloudx_flutter/cloudx.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'arbiter/arbiter_events.dart';
import 'arbiter/arbiter_interstitial_controller.dart';
import 'config/demo_config.dart';
import 'tracking_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CloudX.setMinLogLevel(CloudXLogLevel.verbose);
  runApp(const ArbiterDemoApp());
}

class ArbiterDemoApp extends StatelessWidget {
  const ArbiterDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudX Trusted Arbiter',
      theme: ThemeData(useMaterial3: true),
      home: const ArbiterScreen(),
    );
  }
}

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
   * Order matters. ATT first, because CloudX reads the status at init and never
   * asks for it; then both SDKs; then the controller, because a load issued
   * before CloudX is up waits silently instead of reporting a failure.
   */
  Future<void> _start() async {
    final tracking = await TrackingGate.request();
    if (!mounted) return;
    setState(() => _trackingStatus = tracking.name);

    if (tracking != TrackingStatus.authorized) {
      setState(
        () => _cloudXSdkStatus = 'tracking not authorized - ads cannot load',
      );
      return;
    }

    /*
     * Google Mobile Ads queues loads issued before init completes, so this does
     * not gate the controller; the line only reports readiness.
     */
    unawaited(
      MobileAds.instance.initialize().then((status) {
        if (!mounted) return;
        final adapters = status.adapterStatuses.keys.join(', ');
        debugPrint('[CloudXArbiterDemo] AdMob ready (adapters: $adapters)');
        setState(() => _adMobSdkStatus = 'ready');
      }),
    );

    final configuration = await CloudX.initialize(appKey: _config.appKey);
    if (!mounted) return;
    if (configuration == null) {
      setState(() => _cloudXSdkStatus = 'initialization failed');
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
    setState(() {
      _cloudX = 'loading';
      _adMob = 'loading';
      _arbiter = 'waiting for both sides to settle';
    });
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
