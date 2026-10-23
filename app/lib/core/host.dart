import 'dart:io' show Platform;

import 'models.dart';

/// Which platform Sidekick is running on: the same as dart:io's [Platform],
/// except in the website's preview (the app compiled for a browser, see
/// lib/demo/), where there is no [Platform] and [web] says which device
/// the page shows it as.
abstract final class Host {
  /// Compiled for a browser: the website's preview.
  static const bool isWeb = bool.fromEnvironment('dart.library.js_interop');

  /// The device the preview plays (set by lib/demo/preview_main.dart).
  static DevicePlatform? web;

  static bool get isWindows => isWeb ? web == DevicePlatform.windows : Platform.isWindows;
  static bool get isMacOS => isWeb ? web == DevicePlatform.macos : Platform.isMacOS;
  static bool get isIOS => isWeb ? web == DevicePlatform.ios : Platform.isIOS;
  static bool get isAndroid => isWeb ? web == DevicePlatform.android : Platform.isAndroid;
  static bool get isLinux => isWeb ? web == DevicePlatform.linux : Platform.isLinux;
}
