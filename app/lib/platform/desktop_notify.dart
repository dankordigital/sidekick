import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/host.dart';

/// The computer's own notifications (Notification Center on the Mac,
/// Windows' toasts), for phone notifications and screenshots that arrive.
///
/// Mac: `showNotification` on `sidekick/macos` (UNUserNotificationCenter,
/// asks once). Windows: a toast through PowerShell's WinRT, under the app id
/// the installer gives the Start menu shortcut (`Sidekick.Sidekick`); with
/// no such shortcut (not installed) Windows shows nothing and the caller's
/// in-app notice is all there is.
abstract final class DesktopNotify {
  static const _mac = MethodChannel('sidekick/macos');
  static const appId = 'Sidekick.Sidekick';

  static bool get supported => Host.isMacOS || Host.isWindows;

  static Future<void> show({required String title, String subtitle = '', required String body}) async {
    try {
      if (Host.isMacOS) {
        await _mac.invokeMethod<void>('showNotification', {'title': title, 'subtitle': subtitle, 'body': body});
      } else if (Host.isWindows) {
        await _windowsToast(subtitle.isEmpty ? title : '$title · $subtitle', body);
      }
    } catch (e) {
      debugPrint('Sidekick: notification: $e');
    }
  }

  static Future<void> _windowsToast(String title, String body) async {
    // The text travels in environment variables, so nothing in it can break
    // out of the script.
    const script = r'''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$texts = $xml.GetElementsByTagName('text')
$texts.Item(0).AppendChild($xml.CreateTextNode($env:SK_TITLE)) | Out-Null
$texts.Item(1).AppendChild($xml.CreateTextNode($env:SK_BODY)) | Out-Null
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($env:SK_APP).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
''';
    final encoded = base64.encode([
      for (final unit in script.codeUnits) ...[unit & 0xff, unit >> 8],
    ]);
    await Process.run(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encoded],
      environment: {'SK_TITLE': title, 'SK_BODY': body, 'SK_APP': appId},
    ).timeout(const Duration(seconds: 15));
  }
}
