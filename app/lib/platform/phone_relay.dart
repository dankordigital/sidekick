import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a phone passes on to paired computers by itself:
///
/// * its notifications (Android only: Settings → Show notifications on
///   computers, through Android's notification access; iOS lets no app see
///   other apps' notifications), and
/// * screenshots as soon as they're taken (Settings → Send screenshots to
///   computers; Android reads new screenshots from the photo library, the
///   iPhone watches its library while Sidekick runs).
///
/// Native code calls back on `sidekick/phone`: `notification` {app, title,
/// text} and `screenshot` {path, name} (a copy in the app's temporary folder).
abstract final class PhoneRelay {
  static const _events = MethodChannel('sidekick/phone');
  static const _android = MethodChannel('sidekick/background');
  static const _ios = MethodChannel('sidekick/ios');

  static bool get notificationsSupported => Platform.isAndroid;
  static bool get screenshotsSupported => Platform.isAndroid || Platform.isIOS;

  static void listen({
    required void Function(String app, String title, String text) onNotification,
    required void Function(String path, String name) onScreenshot,
  }) {
    if (!notificationsSupported && !screenshotsSupported) return;
    _events.setMethodCallHandler((call) async {
      final args = (call.arguments as Map?)?.cast<String, Object?>() ?? const {};
      String arg(String key) => args[key] as String? ?? '';
      switch (call.method) {
        case 'notification':
          onNotification(arg('app'), arg('title'), arg('text'));
        case 'screenshot':
          if (arg('path').isNotEmpty) onScreenshot(arg('path'), arg('name'));
      }
      return null;
    });
  }

  /// Android: Sidekick has notification access (Settings → Notification
  /// access / Device & app notifications).
  static Future<bool> notificationAccess() => _ask(_android, 'notificationAccess');

  /// Opens Android's notification access page for Sidekick.
  static Future<void> openNotificationAccess() => _ask(_android, 'openNotificationAccess');

  /// Starts or stops watching for new screenshots. Asks for the photo
  /// permission it needs the first time; false if it wasn't given.
  static Future<bool> watchScreenshots(bool on) =>
      _ask(Platform.isIOS ? _ios : _android, 'watchScreenshots', {'on': on});

  static Future<bool> _ask(MethodChannel channel, String method, [Map<String, Object?>? args]) async {
    try {
      return await channel.invokeMethod<bool>(method, args) ?? false;
    } catch (e) {
      debugPrint('Sidekick: $method: $e');
      return false;
    }
  }
}
