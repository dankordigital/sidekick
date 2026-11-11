// "Open Settings" in the error pop-up: the system's settings for Sidekick,
// where a missing permission (camera, Bluetooth, photos…) is allowed.
import 'package:url_launcher/url_launcher.dart';

import '../core/host.dart';
import 'android.dart';

/// Whether this device can open its settings for Sidekick (not the browser
/// preview).
bool get canOpenSystemSettings => !Host.isWeb && (Host.isAndroid || Host.isIOS || Host.isMacOS || Host.isWindows);

Future<void> openSystemSettings() async {
  try {
    if (Host.isAndroid) return await AndroidBridge.openAppSettings();
    final url = Host.isIOS
        ? 'app-settings:'
        : Host.isMacOS
        ? 'x-apple.systempreferences:com.apple.preference.security?Privacy'
        : 'ms-settings:privacy';
    await launchUrl(Uri.parse(url));
  } catch (_) {
    // Nothing to open here: the pop-up's steps say where to go.
  }
}
