import 'package:cloudx_flutter/cloudx.dart';
import 'package:flutter/services.dart';

/*
 * Opens the CloudX Mediation Debugger, the native screen that lists every
 * adapter the build actually linked with the version it resolved to, the
 * privacy signals, the ad units and the per-network test-ad controls.
 *
 * It lives here rather than in the screen that owns the button because this is
 * an SDK call, and lib/ui is the demo's own scaffolding: a reader following the
 * integration is told to read lib/cloudx and ignore the rest.
 *
 * There is nothing to initialize and no listener to register. The call answers
 * false rather than throwing while the SDK is still uninitialized, so a false
 * is a state to report, not an error.
 *
 * Copy this file on its own; it depends on nothing else in lib/cloudx.
 */
class MediationDebugger {
  const MediationDebugger._();

  /*
   * Null when the debugger opened. Otherwise the one line to show the user,
   * which is all a caller needs to decide: there is no partial success.
   */
  static Future<String?> show() async {
    final bool shown;
    try {
      shown = await CloudX.showMediationDebugger();
    } on PlatformException catch (e) {
      /*
       * message is nullable, and a channel error that carries only a code would
       * otherwise print "failed to open: null". The code is less friendly than
       * a message but it is something to search for.
       */
      return 'Mediation Debugger failed to open: ${e.message ?? e.code}';
    }
    if (shown) {
      return null;
    }
    return 'Initialize CloudX before opening the Mediation Debugger.';
  }
}
