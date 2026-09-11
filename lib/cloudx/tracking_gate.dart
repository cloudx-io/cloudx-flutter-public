import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/widgets.dart';

/*
 * The App Tracking Transparency gate.
 *
 * CloudX reads the ATT status but never asks for it, and treats notDetermined
 * the same as denied: no IDFA and dnt = 1. So the prompt has to be answered
 * before CloudX.initialize runs, and a denied answer is a dead end the app
 * should state rather than hide behind an empty ad slot.
 *
 * iOS only. Android has no ATT and reports authorized straight away.
 *
 * Copy this file with sdk_startup.dart, which calls it. This is the one file in
 * lib/cloudx/ that needs Flutter for something other than logging: it waits on
 * AppLifecycleListener, because iOS refuses to present the prompt while the app
 * is still becoming active and answers notDetermined instead of showing
 * anything. It still builds no widgets.
 */
class TrackingGate {
  const TrackingGate._();

  /*
   * iOS refuses to present the prompt while the app is still becoming active,
   * and answers notDetermined instead of showing anything. A short settle is
   * enough in practice; the Unity demo waits on the same condition.
   */
  static const Duration _settle = Duration(milliseconds: 500);

  /// Requests authorization if it has not been asked for yet, then reports it.
  static Future<TrackingStatus> request() async {
    if (!Platform.isIOS) {
      return TrackingStatus.authorized;
    }

    await _waitUntilActive();
    await Future<void>.delayed(_settle);

    var status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      status = await AppTrackingTransparency.requestTrackingAuthorization();
    }
    return status;
  }

  static Future<void> _waitUntilActive() async {
    final binding = WidgetsBinding.instance;
    if (binding.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    final completer = Completer<void>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );
    await completer.future;
    listener.dispose();
  }
}
