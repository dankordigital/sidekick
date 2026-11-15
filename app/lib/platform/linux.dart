import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'input.dart';

/// Linux (4.0.1): the desktop's own tools, so there's no native code to keep.
abstract final class LinuxDesktop {
  static bool? _xdotool;
  static bool? _ydotool;

  /// Whether `ydotool` (remote control on Wayland, with its `ydotoold`
  /// service running) is installed: used when there's no `xdotool`.
  static bool get hasYdotool => _ydotool ??= _which('ydotool');

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

/// Remote control of a Linux computer: `xdotool` (X11, and X apps under
/// Wayland) or, without it, `ydotool` (Wayland too; its `ydotoold`
/// service must run). Pointer moves are gathered for a frame (16 ms) so a
/// fast swipe isn't a hundred processes.
class LinuxInputInjector implements InputInjector {
  int _dx = 0, _dy = 0;
  Timer? _flush;

  bool get _x11 => LinuxDesktop.hasXdotool;

  @override
  bool get supported => LinuxDesktop.hasXdotool || LinuxDesktop.hasYdotool;

  void _run(List<String> args) {
    if (!supported) return;
    unawaited(Process.run(_x11 ? 'xdotool' : 'ydotool', args).then((_) {}, onError: (_) {}));
  }

  @override
  void moveBy(int dx, int dy) {
    _dx += dx;
    _dy += dy;
    _flush ??= Timer(const Duration(milliseconds: 16), () {
      _flush = null;
      final x = _dx, y = _dy;
      _dx = _dy = 0;
      if (x == 0 && y == 0) return;
      _run(_x11 ? ['mousemove_relative', '--', '$x', '$y'] : ['mousemove', '-x', '$x', '-y', '$y']);
    });
  }

  static String _xButton(MouseButton b) => switch (b) {
    MouseButton.left => '1',
    MouseButton.middle => '2',
    MouseButton.right => '3',
  };

  /// ydotool's buttons: 0 left, 1 right, 2 middle; 0x40 down, 0x80 up.
  static int _yButton(MouseButton b) => switch (b) {
    MouseButton.left => 0,
    MouseButton.right => 1,
    MouseButton.middle => 2,
  };

  static String _hex(int v) => '0x${v.toRadixString(16)}';

  @override
  void button(MouseButton button, {required bool down}) => _run(
    _x11
        ? [down ? 'mousedown' : 'mouseup', _xButton(button)]
        : ['click', _hex(_yButton(button) | (down ? 0x40 : 0x80))],
  );

  @override
  void click(MouseButton button, {int count = 1}) => _run(
    _x11
        ? ['click', '--repeat', '$count', _xButton(button)]
        : ['click', '--repeat', '$count', _hex(_yButton(button) | 0xC0)],
  );

  @override
  void scroll({int dx = 0, int dy = 0}) {
    if (!_x11) {
      // ydotool: a wheel move, in notches (positive y scrolls up).
      final x = (dx / 120).round(), y = (dy / 120).round();
      if (x != 0 || y != 0) _run(['mousemove', '--wheel', '-x', '$x', '-y', '$y']);
      return;
    }
    // 120 is one notch; X scrolls with buttons 4 (up), 5 (down), 6 (left), 7 (right).
    void notches(int amount, String plus, String minus) {
      if (amount == 0) return;
      final n = (amount.abs() / 120).ceil().clamp(1, 10);
      _run(['click', '--repeat', '$n', amount > 0 ? plus : minus]);
    }

    notches(dy, '4', '5');
    notches(dx, '7', '6');
  }

  static const _xKeys = {
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

  static String _xKey(String k) {
    if (_xKeys[k] case final s?) return s;
    if (RegExp(r'^f([1-9]|1[0-2])$').hasMatch(k)) return k.toUpperCase();
    return k;
  }

  /// Linux key codes (input-event-codes.h), for ydotool.
  static const _codes = {
    'esc': 1,
    'backspace': 14,
    'tab': 15,
    'enter': 28,
    'ctrl': 29,
    'macctrl': 29,
    'shift': 42,
    'alt': 56,
    'space': 57,
    'home': 102,
    'up': 103,
    'pageup': 104,
    'left': 105,
    'right': 106,
    'end': 107,
    'down': 108,
    'pagedown': 109,
    'insert': 110,
    'delete': 111,
    'win': 125,
    'cmd': 125,
    'menu': 127,
    'printscreen': 99,
    'f1': 59,
    'f2': 60,
    'f3': 61,
    'f4': 62,
    'f5': 63,
    'f6': 64,
    'f7': 65,
    'f8': 66,
    'f9': 67,
    'f10': 68,
    'f11': 87,
    'f12': 88,
    '1': 2,
    '2': 3,
    '3': 4,
    '4': 5,
    '5': 6,
    '6': 7,
    '7': 8,
    '8': 9,
    '9': 10,
    '0': 11,
    'q': 16,
    'w': 17,
    'e': 18,
    'r': 19,
    't': 20,
    'y': 21,
    'u': 22,
    'i': 23,
    'o': 24,
    'p': 25,
    'a': 30,
    's': 31,
    'd': 32,
    'f': 33,
    'g': 34,
    'h': 35,
    'j': 36,
    'k': 37,
    'l': 38,
    'z': 44,
    'x': 45,
    'c': 46,
    'v': 47,
    'b': 48,
    'n': 49,
    'm': 50,
  };

  @override
  void key(String key, {List<String> modifiers = const []}) {
    if (_x11) {
      _run([
        'key',
        '--clearmodifiers',
        [...modifiers.map(_xKey), _xKey(key)].join('+'),
      ]);
      return;
    }
    final codes = [
      for (final k in [...modifiers, key]) ?_codes[k.toLowerCase()],
    ];
    if (codes.length != modifiers.length + 1) return;
    _run(['key', for (final c in codes) '$c:1', for (final c in codes.reversed) '$c:0']);
  }

  @override
  void text(String text) {
    if (text.isEmpty) return;
    _run(_x11 ? ['type', '--delay', '0', '--', text] : ['type', '--', text]);
  }
}
