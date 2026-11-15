import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/host.dart';
import 'desktop_window.dart';

/// Settings → App icon: the eight "sk" icons (design/logo-sk/, made into
/// every platform's icons by tool/make_icons.py). Ink is the app's own icon (4.0.1; Dusk was in 4.0.0).
/// iPhone: an alternate icon (iOS says it changed); Android: the launcher
/// entry with that icon; Mac: the Dock icon while Sidekick runs; Windows: the
/// window and taskbar icon (the .exe's own can't change). Tray and menu-bar
/// icons stay as they are.
class AppIcon {
  static const _ios = MethodChannel('sidekick/ios');
  static const _android = MethodChannel('sidekick/android');

  static const choices = ['ink', 'dusk', 'paper', 'sky', 'amber', 'mint', 'signal', 'chrome'];
  static const standard = 'ink';

  static String label(String name) => name[0].toUpperCase() + name.substring(1);

  /// The picture shown in Settings.
  static String asset(String name) => 'assets/icons/choice-$name.png';

  /// What was last set, so starts don't ask twice. Mac and Windows start
  /// with their own icon (Ink) every time.
  static String? _applied = DesktopWindow.supported && !Host.isLinux ? standard : null;

  static Future<void> apply(String name) async {
    if (Host.isWeb || _applied == name) return;
    try {
      if (Host.isIOS) {
        await _ios.invokeMethod('setAppIcon', {'name': name == standard ? null : 'AppIcon-${label(name)}'});
      } else if (Host.isAndroid) {
        await _android.invokeMethod('setAppIcon', {'name': name});
      } else if (DesktopWindow.supported) {
        await DesktopWindow.instance.setAppIcon(name, standard: name == standard);
      } else {
        return;
      }
      _applied = name;
    } catch (e) {
      // Not answered (Android in the background, without its screen): it's
      // tried again on the next start or change.
      debugPrint('Sidekick: app icon: $e');
    }
  }
}
