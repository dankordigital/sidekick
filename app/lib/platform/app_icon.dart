import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/host.dart';
import 'desktop_window.dart';

/// Settings → Theme → Nothing changes the app's icon too, and back:
/// iPhone: an alternate icon (iOS says it changed); Android: the launcher
/// entry with the "sk." icon; Mac: the Dock icon while Sidekick runs;
/// Windows: the window and taskbar icon; Mac and Windows: the tray /
/// menu-bar icon. Icons from tool/make_icons.py (nothing()).
class AppIcon {
  static const _ios = MethodChannel('sidekick/ios');
  static const _android = MethodChannel('sidekick/android');

  /// What was last set, so starts and theme changes don't ask twice. Mac and
  /// Windows start with their own icons every time: nothing to do there
  /// unless the Nothing look is on.
  static bool? _applied = DesktopWindow.supported ? false : null;

  static Future<void> apply({required bool nothing}) async {
    if (Host.isWeb || _applied == nothing) return;
    try {
      if (Host.isIOS) {
        await _ios.invokeMethod('setAppIcon', {'name': nothing ? 'AppIcon-Nothing' : null});
      } else if (Host.isAndroid) {
        await _android.invokeMethod('setAppIcon', {'nothing': nothing});
      } else if (DesktopWindow.supported) {
        await DesktopWindow.instance.setNothingIcons(nothing);
      } else {
        return;
      }
      _applied = nothing;
    } catch (e) {
      // Not answered (Android in the background, without its screen): it's
      // tried again on the next start or change.
      debugPrint('Sidekick: app icon: $e');
    }
  }
}
