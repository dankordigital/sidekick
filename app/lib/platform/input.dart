import 'android.dart';
import 'input_windows.dart' if (dart.library.js_interop) 'input_windows_web.dart';
import 'macos.dart';
import '../core/host.dart';

export 'input_windows.dart' if (dart.library.js_interop) 'input_windows_web.dart';

enum MouseButton { left, right, middle }

/// Injects mouse and keyboard events into *this* device.
///
/// Peers drive it over the `/v1/input` WebSocket; see [handleInputMessage].
abstract class InputInjector {
  /// Whether this platform can inject input at all.
  bool get supported;

  void moveBy(int dx, int dy);
  void button(MouseButton button, {required bool down});
  void click(MouseButton button, {int count = 1});

  /// [dy] and [dx] use Windows wheel units: 120 is one notch.
  /// Positive [dy] scrolls up, positive [dx] scrolls right.
  void scroll({int dx = 0, int dy = 0});

  /// Presses and releases [key] (see [keyNames]) while holding [modifiers].
  void key(String key, {List<String> modifiers = const []});

  /// Types arbitrary text.
  void text(String text);

  static InputInjector forCurrentPlatform() {
    // The website's preview, in a browser: nothing to inject into.
    if (const bool.fromEnvironment('dart.library.js_interop')) return UnsupportedInputInjector();
    if (Host.isWindows) return WindowsInputInjector();
    if (Host.isAndroid) return AndroidInputInjector();
    if (Host.isMacOS) return MacInputInjector();
    return UnsupportedInputInjector();
  }
}

/// Names accepted by [InputInjector.key], shared by every platform.
const List<String> keyNames = [
  'enter', 'backspace', 'tab', 'esc', 'space', 'delete', 'insert',
  'left', 'right', 'up', 'down', 'home', 'end', 'pageup', 'pagedown',
  'win', 'ctrl', 'alt', 'shift', 'printscreen', 'menu',
  'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8', 'f9', 'f10', 'f11', 'f12',
  // Android only: global actions.
  'back', 'home', 'recents', 'notifications', 'quicksettings', 'lock',
  // Mac only: modifiers ("ctrl" and "win" already mean Command on a Mac).
  'cmd', 'macctrl',
  // single letters and digits are accepted too: 'a'..'z', '0'..'9'
];

/// Applies one JSON input message from a peer. Unknown or malformed
/// messages are ignored so a buggy client can't crash the server.
///
/// Messages:
///   {"t":"move","dx":3,"dy":-2}
///   {"t":"click","b":"left","n":2}
///   {"t":"down","b":"left"} / {"t":"up","b":"left"}
///   {"t":"scroll","dx":0,"dy":-120}
///   {"t":"key","k":"c","mods":["ctrl"]}
///   {"t":"text","s":"hello"}
void handleInputMessage(InputInjector input, Map<String, dynamic> msg) {
  int intOf(String key, [int fallback = 0]) {
    final v = msg[key];
    return v is num ? v.round().clamp(-100000, 100000) : fallback;
  }

  MouseButton buttonOf() => switch (msg['b']) {
    'right' => MouseButton.right,
    'middle' => MouseButton.middle,
    _ => MouseButton.left,
  };

  switch (msg['t']) {
    case 'move':
      input.moveBy(intOf('dx'), intOf('dy'));
    case 'click':
      input.click(buttonOf(), count: intOf('n', 1).clamp(1, 3));
    case 'down':
      input.button(buttonOf(), down: true);
    case 'up':
      input.button(buttonOf(), down: false);
    case 'scroll':
      input.scroll(dx: intOf('dx'), dy: intOf('dy'));
    case 'key':
      final k = msg['k'];
      final mods = msg['mods'];
      if (k is String) {
        input.key(k, modifiers: mods is List ? mods.whereType<String>().toList() : const []);
      }
    case 'text':
      final s = msg['s'];
      if (s is String && s.length <= 4096) input.text(s);
  }
}

class UnsupportedInputInjector implements InputInjector {
  @override
  bool get supported => false;
  @override
  void moveBy(int dx, int dy) {}
  @override
  void button(MouseButton button, {required bool down}) {}
  @override
  void click(MouseButton button, {int count = 1}) {}
  @override
  void scroll({int dx = 0, int dy = 0}) {}
  @override
  void key(String key, {List<String> modifiers = const []}) {}
  @override
  void text(String text) {}
}
