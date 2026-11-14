import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../core/history.dart';
import '../core/host.dart';
import '../core/models.dart';

/// Sidekick's home-screen widgets on iPhone and Android (4.0): a small one
/// with the last file received (or "Ready to receive"), and a medium one with
/// up to three paired devices, each with Send and Ping.
///
/// The app writes what they show; the widgets only draw it. iPhone: the
/// SidekickLive extension reads it from the App Group (AppDelegate
/// `updateWidgets`). Android: SidekickWidgets.kt reads it from its own
/// preferences (`sidekick/background`, answered even with no screen open).
/// Taps come back as links (`sidekick://send?id=…`, `ping?id=…`, `open`),
/// picked up when Sidekick comes to the front ([takeLink]).
class HomeWidgets {
  static const _ios = MethodChannel('sidekick/ios');
  static const _android = MethodChannel('sidekick/background');

  static bool get supported => Host.isIOS || Host.isAndroid;

  static MethodChannel get _channel => Host.isIOS ? _ios : _android;

  static String? _sent;
  static Timer? _wait;

  /// Called on every change of the app's state: at most once a second, and
  /// only when what the widgets show has changed.
  static void update(AppState state) {
    if (!supported) return;
    _wait?.cancel();
    _wait = Timer(const Duration(seconds: 1), () => unawaited(_push(state)));
  }

  static Future<void> _push(AppState state) async {
    final json = jsonEncode(snapshot(state));
    if (json == _sent) return;
    _sent = json;
    try {
      await _channel.invokeMethod('updateWidgets', {'json': json});
    } catch (e) {
      _sent = null;
      debugPrint('Sidekick: widgets: $e');
    }
  }

  /// What the widgets show (also used by the tests).
  static Map<String, Object?> snapshot(AppState state) {
    HistoryItem? last;
    String? from;
    for (final d in state.paired) {
      for (final item in state.history.forDevice(d.id).reversed) {
        if (item.fromMe || !const {HistoryKind.file, HistoryKind.photo, HistoryKind.video}.contains(item.kind)) {
          continue;
        }
        if (last == null || item.at.isAfter(last.at)) {
          last = item;
          from = d.name;
        }
        break;
      }
    }
    final devices = [...state.paired]
      ..sort((a, b) {
        final online = (state.isOnline(b.id) ? 1 : 0) - (state.isOnline(a.id) ? 1 : 0);
        return online != 0 ? online : a.name.compareTo(b.name);
      });
    return {
      'last': last == null ? null : {'name': last.name ?? 'A file', 'from': from, 'at': last.at.millisecondsSinceEpoch},
      'devices': [
        for (final d in devices.take(3))
          {
            'id': d.id,
            'name': d.name,
            'kind': switch (d.platform) {
              DevicePlatform.ios || DevicePlatform.android => 'phone',
              DevicePlatform.macos => 'laptop',
              _ => 'desktop',
            },
            'online': state.isOnline(d.id),
          },
      ],
    };
  }

  /// The widget the person tapped, if one opened Sidekick (once each).
  static Future<Uri?> takeLink() async {
    if (!supported) return null;
    try {
      final link = await _channel.invokeMethod<String>('takeWidgetLink');
      return link == null ? null : Uri.tryParse(link);
    } catch (_) {
      return null;
    }
  }
}
