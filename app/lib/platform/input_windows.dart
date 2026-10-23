// Windows input for [InputInjector]: user32's SendInput through dart:ffi.
// Its own file so the browser preview (no dart:ffi) can leave it out; see
// input_windows_web.dart.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'input.dart';

// ---------------------------------------------------------------------------
// Windows: user32!SendInput via dart:ffi.
//
// The structs below mirror the Win32 INPUT / MOUSEINPUT / KEYBDINPUT layout.
// dart:ffi handles padding and alignment for both x64 and arm64.
// ---------------------------------------------------------------------------

final class _MouseInput extends Struct {
  @Int32()
  external int dx;
  @Int32()
  external int dy;
  @Uint32()
  external int mouseData;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;
  @IntPtr()
  external int dwExtraInfo;
}

final class _KeybdInput extends Struct {
  @Uint16()
  external int wVk;
  @Uint16()
  external int wScan;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;
  @IntPtr()
  external int dwExtraInfo;
}

/// MOUSEINPUT is the largest member, so this matches the Win32 union size.
final class _InputUnion extends Union {
  external _MouseInput mi;
  external _KeybdInput ki;
}

final class _Input extends Struct {
  @Uint32()
  external int type;
  external _InputUnion u;
}

typedef _SendInputNative = Uint32 Function(Uint32, Pointer<_Input>, Int32);
typedef _SendInputDart = int Function(int, Pointer<_Input>, int);

const _inputMouse = 0;
const _inputKeyboard = 1;

const _mouseMove = 0x0001;
const _mouseLeftDown = 0x0002;
const _mouseLeftUp = 0x0004;
const _mouseRightDown = 0x0008;
const _mouseRightUp = 0x0010;
const _mouseMiddleDown = 0x0020;
const _mouseMiddleUp = 0x0040;
const _mouseWheel = 0x0800;
const _mouseHWheel = 0x1000;

const _keyExtended = 0x0001;
const _keyUp = 0x0002;
const _keyUnicode = 0x0004;

/// Virtual-key codes for the names in [keyNames].
const Map<String, int> _vk = {
  'backspace': 0x08,
  'tab': 0x09,
  'enter': 0x0D,
  'shift': 0x10,
  'ctrl': 0x11,
  'alt': 0x12,
  'esc': 0x1B,
  'space': 0x20,
  'pageup': 0x21,
  'pagedown': 0x22,
  'end': 0x23,
  'home': 0x24,
  'left': 0x25,
  'up': 0x26,
  'right': 0x27,
  'down': 0x28,
  'printscreen': 0x2C,
  'insert': 0x2D,
  'delete': 0x2E,
  'win': 0x5B,
  'menu': 0x5D,
  'f1': 0x70,
  'f2': 0x71,
  'f3': 0x72,
  'f4': 0x73,
  'f5': 0x74,
  'f6': 0x75,
  'f7': 0x76,
  'f8': 0x77,
  'f9': 0x78,
  'f10': 0x79,
  'f11': 0x7A,
  'f12': 0x7B,
};

/// Keys that need KEYEVENTF_EXTENDEDKEY to behave correctly.
const Set<int> _extendedVk = {0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x2C, 0x2D, 0x2E, 0x5B, 0x5D};

int? virtualKeyFor(String name) {
  final lower = name.toLowerCase();
  final named = _vk[lower];
  if (named != null) return named;
  if (lower.length == 1) {
    final c = lower.codeUnitAt(0);
    if (c >= 0x61 && c <= 0x7A) return c - 0x20; // a-z → VK_A..VK_Z
    if (c >= 0x30 && c <= 0x39) return c; // 0-9
  }
  return null;
}

/// Size of the INPUT struct passed to SendInput. Windows rejects the call if
/// this is wrong, so it's pinned in a test (40 bytes on 64-bit Windows).
int get inputStructSize => sizeOf<_Input>();

class WindowsInputInjector implements InputInjector {
  WindowsInputInjector();

  late final _SendInputDart _sendInput = DynamicLibrary.open('user32.dll')
      .lookupFunction<_SendInputNative, _SendInputDart>('SendInput');

  @override
  bool get supported => true;

  void _send(List<void Function(_Input)> events) {
    if (events.isEmpty) return;
    using((arena) {
      final inputs = arena<_Input>(events.length); // zero-filled
      for (var i = 0; i < events.length; i++) {
        events[i](inputs[i]);
      }
      _sendInput(events.length, inputs, sizeOf<_Input>());
    });
  }

  void Function(_Input) _mouse(int flags, {int dx = 0, int dy = 0, int data = 0}) => (i) {
    i.type = _inputMouse;
    i.u.mi
      ..dx = dx
      ..dy = dy
      ..mouseData = data & 0xFFFFFFFF
      ..dwFlags = flags;
  };

  void Function(_Input) _vkEvent(int vk, {required bool up}) => (i) {
    var flags = up ? _keyUp : 0;
    if (_extendedVk.contains(vk)) flags |= _keyExtended;
    i.type = _inputKeyboard;
    i.u.ki
      ..wVk = vk
      ..dwFlags = flags;
  };

  void Function(_Input) _unicodeEvent(int codeUnit, {required bool up}) => (i) {
    i.type = _inputKeyboard;
    i.u.ki
      ..wScan = codeUnit
      ..dwFlags = _keyUnicode | (up ? _keyUp : 0);
  };

  static (int down, int up) _buttonFlags(MouseButton b) => switch (b) {
    MouseButton.left => (_mouseLeftDown, _mouseLeftUp),
    MouseButton.right => (_mouseRightDown, _mouseRightUp),
    MouseButton.middle => (_mouseMiddleDown, _mouseMiddleUp),
  };

  @override
  void moveBy(int dx, int dy) => _send([_mouse(_mouseMove, dx: dx, dy: dy)]);

  @override
  void button(MouseButton button, {required bool down}) {
    final (d, u) = _buttonFlags(button);
    _send([_mouse(down ? d : u)]);
  }

  @override
  void click(MouseButton button, {int count = 1}) {
    final (d, u) = _buttonFlags(button);
    _send([
      for (var i = 0; i < count; i++) ...[_mouse(d), _mouse(u)],
    ]);
  }

  @override
  void scroll({int dx = 0, int dy = 0}) =>
      _send([if (dy != 0) _mouse(_mouseWheel, data: dy), if (dx != 0) _mouse(_mouseHWheel, data: dx)]);

  @override
  void key(String key, {List<String> modifiers = const []}) {
    final vk = virtualKeyFor(key);
    if (vk == null) return;
    final mods = modifiers.map(virtualKeyFor).whereType<int>().toList();
    _send([
      for (final m in mods) _vkEvent(m, up: false),
      _vkEvent(vk, up: false),
      _vkEvent(vk, up: true),
      for (final m in mods.reversed) _vkEvent(m, up: true),
    ]);
  }

  @override
  void text(String text) => _send([
    for (final unit in text.codeUnits) ...[
      if (unit == 0x0A) ..._enter() else ...[_unicodeEvent(unit, up: false), _unicodeEvent(unit, up: true)],
    ],
  ]);

  List<void Function(_Input)> _enter() => [_vkEvent(0x0D, up: false), _vkEvent(0x0D, up: true)];
}
