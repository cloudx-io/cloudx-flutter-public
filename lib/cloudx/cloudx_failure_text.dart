import 'package:cloudx_flutter/cloudx.dart';

/*
 * Turns a CloudX failure into the one line the status rows show.
 *
 * The point is the code name. A no-fill and a misconfigured ad unit read the
 * same way when only the message is printed, and a bare number says little more
 * unless you already know the table. Since 3.9.0 the SDK carries its own name
 * for the code on both platforms, so a round that did not fill says
 * NO_FILL[302] and an ad unit that is wrong for the app key says
 * INVALID_AD_UNIT[300]. Both of those were seen on Android and iOS.
 *
 * Which code a given failure carries is the SDK's business, not this file's:
 * an app key the backend rejects arrives as NETWORK_CLIENT_ERROR[103] rather
 * than INVALID_APP_KEY[203], because it is the HTTP response that failed. Read
 * the name the SDK sent instead of predicting it.
 *
 * The name is what the native SDK reported, not a second table kept here that
 * could drift from it. It is null when the SDK reported a code the plugin
 * cannot name, and the line then falls back to the number.
 *
 * Copy this file with sdk_startup.dart and arbiter_interstitial_controller.dart
 * if you keep either; both format their failures through it.
 */
class CloudXFailureText {
  const CloudXFailureText._();

  /// A load or show failure delivered through a listener.
  static String of(CloudXError error) =>
      _format(error.message, error.codeName, error.code);

  /*
   * An initialize failure. Null when the result is a success, so a caller
   * cannot print a reason for something that did not fail.
   */
  static String? ofInitialization(CloudXInitializationResult result) {
    if (result.success) {
      return null;
    }
    return _format(
      result.message ?? 'unknown error',
      result.errorCodeName,
      result.errorCode,
    );
  }

  /*
   * Both halves are optional on their own: initialize reports no code at all
   * when the failure never reached the native SDK, and the name is absent for
   * a code the plugin cannot name. Whatever is present is shown.
   */
  static String _format(String rawMessage, String? name, int? code) {
    /*
     * Trimmed because the native message is not always one line: an Android
     * initialize failure against a bad app key arrives as
     * 'HTTP 401: {"message":"missing or malformed App Key"}\n', and the
     * newline would push the code onto a line of its own in both the status
     * row and the log.
     */
    final message = rawMessage.trim();
    if (code == null) {
      return name == null ? message : '$message ($name)';
    }
    final described = name == null ? '$code' : '$name[$code]';
    return '$message ($described)';
  }
}
