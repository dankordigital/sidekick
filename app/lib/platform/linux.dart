import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'input.dart';

/// Linux (4.0.1): the desktop's own tools, so there's no native code to keep.
abstract final class LinuxDesktop {
  static bool? _xdotool;

  /// Whether `xdotool` (remote control: pointer and keys) is installed. It
  /// works on X11 and in XWayland windows.
  static bool get hasXdotool => _xdotool ??= _which('xdotool');

  static bool _which(String tool) {
    try {
      return Process.runSync('which', [tool]).exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Opens a folder or file in the file manager.
  static Future<void> open(String path) => _run('xdg-open', [path]);

  /// A desktop notification (`notify-send`, in every desktop).
  static Future<void> notify(String title, String body) =>
      _run('notify-send', ['--app-name=Sidekick', '--icon=dev.sidekick.sidekick', title, body]);

  /// Plays a WAV file (PulseAudio / PipeWire's `paplay`, else ALSA's `aplay`).
  static Future<Process?> play(String wav) async {
    for (final player in ['paplay', 'aplay']) {
      try {
        return await Process.start(player, [wav]);
      } catch (_) {}
    }
    return null;
  }

  static Future<void> _run(String tool, List<String> args) async {
    try {
      await Process.run(tool, args);
    } catch (e) {
      debugPrint('Sidekick: $tool: $e');
    }
  }

  /// Settings → Open when you log in: `~/.config/autostart/sidekick.desktop`.
  static Future<void> autostart(bool on) async {
    final home = Platform.environment['HOME'];
    if (home == null) return;
    final file = File('$home/.config/autostart/sidekick.desktop');
    if (!on) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=Sidekick\n'
      'Exec=env SIDEKICK_HIDDEN=1 "${Platform.resolvedExecutable}"\n'
      'Icon=dev.sidekick.sidekick\n'
      'X-GNOME-Autostart-enabled=true\n',
    );
  }
}

/// Remote control of a Linux computer through `xdotool`. Pointer moves are
/// gathered for a frame (16 ms) so a fast swipe isn't a hundred processes.
class LinuxInputInjector implements InputInjector {
  int _dx = 0, _dy = 0;
  Timer? _flush;

  @override
  bool get supported => LinuxDesktop.hasXdotool;

  void _x(List<String> args) {
    if (!supported) return;
    unawaited(Process.run('xdotool', args).then((_) {}, onError: (_) {}));
  }

  @override
  void moveBy(int dx, int dy) {
    _dx += dx;
    _dy += dy;
    _flush ??= Timer(const Duration(milliseconds: 16), () {
      _flush = null;
      final x = _dx, y = _dy;
      _dx = _dy = 0;
      if (x != 0 || y != 0) _x(['mousemove_relative', '--', '$x', '$y']);
    });
  }

  static String _b(MouseButton b) => switch (b) {
    MouseButton.left => '1',
    MouseButton.middle => '2',
    MouseButton.right => '3',
  };

  @override
  void button(MouseButton button, {required bool down}) => _x([down ? 'mousedown' : 'mouseup', _b(button)]);

  @override
  void click(MouseButton button, {int count = 1}) => _x(['click', '--repeat', '$count', _b(button)]);

  @override
  void scroll({int dx = 0, int dy = 0}) {
    // 120 is one notch; X scrolls with buttons 4 (up), 5 (down), 6 (left), 7 (right).
    void notches(int amount, String plus, String minus) {
      if (amount == 0) return;
      final n = (amount.abs() / 120).ceil().clamp(1, 10);
      _x(['click', '--repeat', '$n', amount > 0 ? plus : minus]);
    }

    notches(dy, '4', '5');
    notches(dx, '7', '6');
  }

  static const _keys = {
    'enter': 'Return',
    'backspace': 'BackSpace',
    'tab': 'Tab',
    'esc': 'Escape',
    'space': 'space',
    'delete': 'Delete',
    'insert': 'Insert',
    'left': 'Left',
    'right': 'Right',
    'up': 'Up',
    'down': 'Down',
    'home': 'Home',
    'end': 'End',
    'pageup': 'Prior',
    'pagedown': 'Next',
    'win': 'super',
    'cmd': 'super',
    'ctrl': 'ctrl',
    'macctrl': 'ctrl',
    'alt': 'alt',
    'shift': 'shift',
    'printscreen': 'Print',
    'menu': 'Menu',
  };

  static String _key(String k) {
    if (_keys[k] case final s?) return s;
    if (RegExp(r'^f([1-9]|1[0-2])$').hasMatch(k)) return k.toUpperCase();
    return k;
  }

  @override
  void key(String key, {List<String> modifiers = const []}) => _x([
    'key',
    '--clearmodifiers',
    [...modifiers.map(_key), _key(key)].join('+'),
  ]);

  @override
  void text(String text) {
    if (text.isNotEmpty) _x(['type', '--delay', '0', '--', text]);
  }
}
