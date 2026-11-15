import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/errors.dart';
import '../core/client.dart';
import '../core/models.dart';
import 'kit.dart';
import 'widgets.dart';
import '../core/host.dart';

/// What to send so text that reads [before] ends up reading [after]:
/// that many backspaces, then [insert]. Handles autocorrect rewrites.
(int backspaces, String insert) typingDiff(String before, String after) {
  var common = 0;
  while (common < before.length && common < after.length && before.codeUnitAt(common) == after.codeUnitAt(common)) {
    common++;
  }
  return (before.length - common, after.substring(common));
}

class RemotePage extends StatelessWidget {
  const RemotePage({super.key, required this.state, this.onGoToDevices});
  final AppState state;
  final VoidCallback? onGoToDevices;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => DeviceGate(
      state: state,
      feature: 'remote control',
      icon: Icons.mouse_outlined,
      onGoToDevices: onGoToDevices,
      builder: (context, device) => device.platform == DevicePlatform.ios
          ? _IphoneCantBeControlled(key: ValueKey(device.id), state: state, device: device)
          : _Remote(key: ValueKey(device.id), state: state, device: device),
    ),
  );
}

/// Shown once, the first time this device meets an iPhone (paired with it,
/// or picked it in Remote): Apple doesn't let any app control an iPhone.
Future<void> showIphoneRemoteNotice(BuildContext context, AppState state, String name) async {
  if (state.iphoneRemoteNoticeSeen) return;
  state.markIphoneRemoteNoticeSeen();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.phone_iphone_rounded),
      title: const Text("iPhones can't be controlled"),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Text(
          "Apple doesn't let any app move the pointer or type on an iPhone, so $name can't be controlled "
          'from here. Everything else works: send files both ways, and use the iPhone as a touchpad and '
          'keyboard for your computer.',
          textAlign: TextAlign.center,
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
    ),
  );
}

/// Remote on an iPhone: no touchpad or keyboard (it can't be controlled),
/// just why, and the picker to choose another device.
class _IphoneCantBeControlled extends StatefulWidget {
  const _IphoneCantBeControlled({super.key, required this.state, required this.device});
  final AppState state;
  final PairedDevice device;

  @override
  State<_IphoneCantBeControlled> createState() => _IphoneCantBeControlledState();
}

class _IphoneCantBeControlledState extends State<_IphoneCantBeControlled> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(showIphoneRemoteNotice(context, widget.state, widget.device.name));
    });
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
    children: [
      const KTitle('Remote'),
      const SizedBox(height: 16),
      const KSub('A little more room to move.'),
      const SizedBox(height: 22),
      KDevicePicker(state: widget.state, device: widget.device, onPick: (d) => widget.state.select(d.id)),
      const SizedBox(height: 16),
      KPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.smartphone_outlined, size: 24, color: K.text),
            const SizedBox(height: 14),
            const Text(
              "iPhones can't be controlled",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: K.text),
            ),
            const SizedBox(height: 10),
            KSub(
              'You can still send files and links, browse shared files, or ping this iPhone. Choose a '
              'computer to use the touchpad.',
            ),
            if (widget.state.paired.any((d) => d.platform != DevicePlatform.ios)) ...[
              const SizedBox(height: 16),
              KPill(
                'Choose a computer',
                onPressed: () => showActions(
                  context,
                  title: 'Choose a computer',
                  options: [
                    for (final d in widget.state.paired)
                      if (d.platform != DevicePlatform.ios)
                        (d.name, deviceIcon(d.platform), () => widget.state.select(d.id)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

enum _Conn { connecting, connected, failed }

class _Remote extends StatefulWidget {
  const _Remote({super.key, required this.state, required this.device});
  final AppState state;
  final PairedDevice device;

  @override
  State<_Remote> createState() => _RemoteState();
}

class _RemoteState extends State<_Remote> {
  InputSession? _session;
  _Conn _conn = _Conn.connecting;
  String? _error;
  double _speed = 1.6;
  bool _holding = false;
  final _captureFocus = FocusNode();
  final _textController = TextEditingController();
  final _liveController = TextEditingController();
  String _live = '';

  bool get _online => widget.state.isOnline(widget.device.id);
  late bool _wasOnline = _online;

  /// Tries in a row after the connection dropped by itself.
  int _redials = 0;

  @override
  void initState() {
    super.initState();
    if (_online) {
      _connect();
    } else {
      _conn = _Conn.failed;
    }
  }

  @override
  void didUpdateWidget(_Remote old) {
    super.didUpdateWidget(old);
    // Back in reach: connect again without being asked.
    final online = _online;
    if (online && !_wasOnline && _conn == _Conn.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connect();
      });
    }
    _wasOnline = online;
  }

  @override
  void dispose() {
    if (_holding) _session?.buttonUp();
    _session?.close();
    _captureFocus.dispose();
    _textController.dispose();
    _liveController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _conn = _Conn.connecting;
      _error = null;
    });
    try {
      // Remote control needs Wi-Fi; over Bluetooth, set up a direct link.
      final id = widget.device.id;
      if (widget.state.viaBluetooth(id) || widget.state.viaDirectLinkOnly(id)) {
        await widget.state.connectDirect(widget.device);
      }
      final session = await widget.state.clientFor(widget.device).openInput();
      if (!mounted) {
        await session.close();
        return;
      }
      setState(() {
        _session = session;
        _conn = _Conn.connected;
        _redials = 0;
      });
      unawaited(
        session.closed.then((_) {
          if (!mounted || _session != session) return;
          // Wi-Fi blinked or the other device slept: dial again, a few times.
          if (_redials < 3) {
            _redials++;
            Timer(Duration(seconds: _redials), () {
              if (mounted && _session == session) _connect();
            });
            setState(() => _conn = _Conn.connecting);
            return;
          }
          setState(() {
            _conn = _Conn.failed;
            _error =
                "The connection to ${widget.device.name} dropped and didn't come back. Check that Sidekick is open on it, then tap Reconnect.";
          });
        }),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _conn = _Conn.failed;
          _error = describeError(e);
        });
      }
    }
  }

  InputSession? get _s => _conn == _Conn.connected ? _session : null;

  /// Forwards physical key presses while the capture box has focus.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final s = _s;
    if (s == null || event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    // A Mac user presses Cmd where a Windows user presses Ctrl. Translate
    // so Cmd+C on a Mac copies on a Windows PC, and Control stays Control
    // when Mac controls Mac.
    final targetMac = widget.device.platform == DevicePlatform.macos;
    final fromMac = Host.isMacOS;
    final mods = [
      if (keyboard.isControlPressed) fromMac && targetMac ? 'macctrl' : 'ctrl',
      if (keyboard.isAltPressed) 'alt',
      if (keyboard.isShiftPressed) 'shift',
      if (keyboard.isMetaPressed) fromMac ? (targetMac ? 'cmd' : 'ctrl') : 'win',
    ];
    final special = _specialKeys[event.logicalKey];
    if (special != null) {
      s.key(special, modifiers: mods);
      return KeyEventResult.handled;
    }
    final label = event.logicalKey.keyLabel.toLowerCase();
    final hasCommandMod = mods.any((m) => m != 'shift');
    if (hasCommandMod && label.length == 1) {
      s.key(label, modifiers: mods);
      return KeyEventResult.handled;
    }
    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 0x20) {
      s.text(char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static final _specialKeys = {
    LogicalKeyboardKey.enter: 'enter',
    LogicalKeyboardKey.backspace: 'backspace',
    LogicalKeyboardKey.tab: 'tab',
    LogicalKeyboardKey.escape: 'esc',
    LogicalKeyboardKey.delete: 'delete',
    LogicalKeyboardKey.arrowLeft: 'left',
    LogicalKeyboardKey.arrowRight: 'right',
    LogicalKeyboardKey.arrowUp: 'up',
    LogicalKeyboardKey.arrowDown: 'down',
    LogicalKeyboardKey.home: 'home',
    LogicalKeyboardKey.end: 'end',
    LogicalKeyboardKey.pageUp: 'pageup',
    LogicalKeyboardKey.pageDown: 'pagedown',
    for (var i = 1; i <= 12; i++) LogicalKeyboardKey.findKeyByKeyId(LogicalKeyboardKey.f1.keyId + i - 1)!: 'f$i',
  };

  /// Keyboard open (phones: the typing box; computers: capture + send text).
  bool _keyboard = false;

  void _pick(PairedDevice d) {
    widget.state.select(d.id);
  }

  Future<void> _speedSheet() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: K.panel,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pointer speed',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: K.text),
              ),
              Slider(
                value: _speed,
                min: 0.5,
                max: 4,
                onChanged: (v) {
                  setState(() => _speed = v);
                  setSheet(() {});
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// The four the design shows up front; the rest are under More.
  bool _main((String, String, List<String>) s) => const {
    'Start menu', 'Switch window', 'Show desktop', 'Lock PC', // Windows
    'Spotlight', 'Switch app', 'Lock Mac', // Mac (and Show desktop)
    'Back', 'Home', 'Recent apps', 'Lock screen', // Android
  }.contains(s.$1);

  Future<void> _more() => showActions(
    context,
    title: 'More shortcuts',
    options: [
      ('Pointer speed', Icons.speed_rounded, _speedSheet),
      for (final (label, key, mods) in _shortcutsFor(widget.device.platform))
        if (!_main((label, key, mods)))
          (label, Icons.keyboard_command_key_rounded, _s == null ? null : () => _s!.key(key, modifiers: mods)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final supported = widget.state.capabilitiesOf(widget.device.id)?.input ?? true;
    final ready = _s != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        const KTitle('Remote'),
        const SizedBox(height: 16),
        const KSub('A little more room to move.'),
        const SizedBox(height: 22),
        KDevicePicker(
          state: widget.state,
          device: widget.device,
          onPick: _pick,
          only: (d) => d.platform != DevicePlatform.ios,
        ),
        const SizedBox(height: 16),
        if (!_online)
          KPanel(
            child: UnreachableDevice(state: widget.state, device: widget.device),
          )
        else ...[
          OfflineBanner(state: widget.state, device: widget.device),
          if (!supported)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: KSub(
                "${widget.device.name} doesn't allow remote control. On ${widget.device.name}, open Sidekick → "
                'Settings and turn on Control mouse and keyboard.',
              ),
            ),
          if (_conn == _Conn.failed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_error ?? "Couldn't connect", style: const TextStyle(fontSize: 13.5, color: K.red)),
                  ),
                  const SizedBox(width: 10),
                  KPill('Reconnect', style: KPillStyle.white, small: true, onPressed: _connect),
                ],
              ),
            ),
          _Touchpad(
            enabled: ready,
            connecting: _conn == _Conn.connecting,
            onMove: (d) => _s?.move(d.dx * _speed, d.dy * _speed),
            onClick: () => _s?.click(),
            onRightClick: () => _s?.click(button: 'right'),
            onScroll: (dx, dy) => _s?.scroll(dx: dx, dy: dy),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                // Hold it to keep the button down (dragging, selecting).
                child: GestureDetector(
                  onLongPress: ready
                      ? () {
                          HapticFeedback.mediumImpact();
                          _holding ? _s!.buttonUp() : _s!.buttonDown();
                          setState(() => _holding = !_holding);
                        }
                      : null,
                  child: KPill(
                    _holding ? 'Holding' : 'Left click',
                    style: _holding ? KPillStyle.white : KPillStyle.dark,
                    onPressed: !ready
                        ? null
                        : _holding
                        ? () {
                            _s!.buttonUp();
                            setState(() => _holding = false);
                          }
                        : () => _s!.click(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KPill(
                  'Right click',
                  style: KPillStyle.dark,
                  onPressed: ready ? () => _s!.click(button: 'right') : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KPill(
                  'Keyboard',
                  style: _keyboard ? KPillStyle.white : KPillStyle.dark,
                  onPressed: ready ? () => setState(() => _keyboard = !_keyboard) : null,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 320),
            curve: const Cubic(0.22, 1, 0.36, 1),
            alignment: Alignment.topCenter,
            child: _keyboard
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: isMobile ? [_liveTyping()] : _desktopKeyboard(Theme.of(context).colorScheme),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 20),
          const KLabel('Shortcuts'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, key, mods) in _shortcutsFor(widget.device.platform).where(_main))
                KPill(
                  label,
                  style: KPillStyle.outline,
                  onPressed: ready ? () => _s!.key(key, modifiers: mods) : null,
                ),
              KPill('More', style: KPillStyle.outline, icon: Icons.more_horiz_rounded, onPressed: _more),
            ],
          ),
          const SizedBox(height: 16),
          KSub('Keep Sidekick open on ${widget.device.name}.', size: 12.5),
        ],
      ],
    );
  }

  /// Physical-keyboard capture and a send-text box, for desktops.
  List<Widget> _desktopKeyboard(ColorScheme scheme) => [
    Focus(
      focusNode: _captureFocus,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: _captureFocus,
        builder: (context, _) {
          final active = _captureFocus.hasFocus;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _s == null ? null : () => active ? _captureFocus.unfocus() : _captureFocus.requestFocus(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: active ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(active ? 28 : 20),
                border: Border.all(color: active ? scheme.primary : Colors.transparent, width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    active ? Icons.keyboard : Icons.keyboard_outlined,
                    color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      active
                          ? 'Typing on ${widget.device.name}. Everything you type goes there. Click here to stop.'
                          : 'Click here, then type. Your keystrokes go straight to ${widget.device.name}.',
                      style: TextStyle(color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _textController,
      enabled: _s != null,
      decoration: InputDecoration(
        hintText: 'Or write text here and press Enter to send it all at once',
        suffixIcon: IconButton(
          tooltip: 'Send text',
          icon: const Icon(Icons.send),
          onPressed: () {
            _s?.text(_textController.text);
            _textController.clear();
          },
        ),
      ),
      onSubmitted: (v) {
        _s?.text(v);
        _textController.clear();
      },
    ),
  ];

  /// On phones: a text field that forwards every change as you type,
  /// including backspaces and autocorrect rewrites.
  Widget _liveTyping() => TextField(
    controller: _liveController,
    enabled: _s != null,
    autocorrect: false,
    enableSuggestions: false,
    textInputAction: TextInputAction.send,
    decoration: InputDecoration(
      hintText: 'Type here to type on ${widget.device.name}',
      prefixIcon: const Icon(Icons.keyboard_outlined),
    ),
    onChanged: _onLiveChanged,
    // Keep the keyboard open after Enter.
    onEditingComplete: () {},
    onSubmitted: (_) {
      _s?.key('enter');
      _liveController.clear();
      _live = '';
    },
  );

  void _onLiveChanged(String value) {
    final s = _s;
    if (s == null) return;
    final (backspaces, insert) = typingDiff(_live, value);
    for (var i = 0; i < backspaces; i++) {
      s.key('backspace');
    }
    if (insert.isNotEmpty) s.text(insert);
    _live = value;
  }

  static List<(String, String, List<String>)> _shortcutsFor(DevicePlatform target) => switch (target) {
    DevicePlatform.android || DevicePlatform.ios => _phoneShortcuts,
    DevicePlatform.macos => _macShortcuts,
    _ => _shortcuts,
  };

  static const _macShortcuts = <(String, String, List<String>)>[
    ('Esc', 'esc', []),
    ('Tab', 'tab', []),
    ('Return', 'enter', []),
    ('Delete', 'backspace', []),
    ('←', 'left', []),
    ('→', 'right', []),
    ('↑', 'up', []),
    ('↓', 'down', []),
    ('Spotlight', 'space', ['cmd']),
    ('Switch app', 'tab', ['cmd']),
    ('Mission Control', 'up', ['macctrl']),
    ('Show desktop', 'f11', []),
    ('Copy', 'c', ['cmd']),
    ('Paste', 'v', ['cmd']),
    ('Undo', 'z', ['cmd']),
    ('Full screen', 'f', ['cmd', 'macctrl']),
    ('Close window', 'w', ['cmd']),
    ('Lock Mac', 'q', ['cmd', 'macctrl']),
  ];

  static const _phoneShortcuts = <(String, String, List<String>)>[
    ('Back', 'back', []),
    ('Home', 'home', []),
    ('Recent apps', 'recents', []),
    ('Notifications', 'notifications', []),
    ('Quick settings', 'quicksettings', []),
    ('Enter', 'enter', []),
    ('Backspace', 'backspace', []),
    ('Select all', 'a', ['ctrl']),
    ('Copy', 'c', ['ctrl']),
    ('Paste', 'v', ['ctrl']),
    ('Lock screen', 'lock', []),
  ];

  static const _shortcuts = <(String, String, List<String>)>[
    ('Esc', 'esc', []),
    ('Tab', 'tab', []),
    ('Enter', 'enter', []),
    ('Backspace', 'backspace', []),
    ('←', 'left', []),
    ('→', 'right', []),
    ('↑', 'up', []),
    ('↓', 'down', []),
    ('Start menu', 'win', []),
    ('Switch window', 'tab', ['alt']),
    ('Show desktop', 'd', ['win']),
    ('Copy', 'c', ['ctrl']),
    ('Paste', 'v', ['ctrl']),
    ('Undo', 'z', ['ctrl']),
    ('Fullscreen (F11)', 'f11', []),
    ('Close window', 'f4', ['alt']),
    ('Lock PC', 'l', ['win']),
  ];
}

/// The design's touchpad: a dotted #1c1c1c panel; one finger moves the
/// pointer (a white dot follows it), tap clicks, hold or right-click is a
/// right click, two fingers or the wheel scroll.
class _Touchpad extends StatefulWidget {
  const _Touchpad({
    required this.enabled,
    required this.connecting,
    required this.onMove,
    required this.onClick,
    required this.onRightClick,
    required this.onScroll,
  });

  final bool enabled;
  final bool connecting;
  final void Function(Offset delta) onMove;
  final VoidCallback onClick;
  final VoidCallback onRightClick;
  final void Function(int dx, int dy) onScroll;

  @override
  State<_Touchpad> createState() => _TouchpadState();
}

class _TouchpadState extends State<_Touchpad> {
  bool _active = false;
  Offset? _dot;
  Offset _scrollRemainder = Offset.zero;

  void _scrollBy(Offset delta) {
    // Flutter reports pixels; Windows wants 120 units per wheel notch. One
    // notch in Flutter is usually ~100 px, so scale a little.
    final total = _scrollRemainder + delta * 1.2;
    final dx = total.dx.truncate(), dy = total.dy.truncate();
    _scrollRemainder = total - Offset(dx.toDouble(), dy.toDouble());
    if (dx != 0 || dy != 0) widget.onScroll(dx, -dy);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Touchpad',
      child: Listener(
        onPointerSignal: (e) {
          if (widget.enabled && e is PointerScrollEvent) _scrollBy(e.scrollDelta);
        },
        child: GestureDetector(
          onTap: widget.enabled ? widget.onClick : null,
          onSecondaryTap: widget.enabled ? widget.onRightClick : null,
          onLongPress: widget.enabled ? widget.onRightClick : null,
          onScaleStart: widget.enabled
              ? (d) => setState(() {
                  _active = true;
                  _dot = d.localFocalPoint;
                })
              : null,
          onScaleUpdate: widget.enabled
              ? (d) {
                  setState(() => _dot = d.localFocalPoint);
                  if (d.pointerCount >= 2) {
                    _scrollBy(-d.focalPointDelta);
                  } else {
                    widget.onMove(d.focalPointDelta);
                  }
                }
              : null,
          onScaleEnd: widget.enabled ? (_) => setState(() => _active = false) : null,
          child: AnimatedScale(
            scale: _active ? 0.99 : 1,
            duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
            curve: const Cubic(0.22, 1, 0.36, 1),
            child: Container(
              height: 300,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: K.panel, borderRadius: BorderRadius.circular(22)),
              child: LayoutBuilder(
                builder: (context, box) {
                  final dot = _dot ?? Offset(box.maxWidth / 2, 120);
                  return Stack(
                    children: [
                      const Positioned.fill(child: CustomPaint(painter: _DotGrid())),
                      // Where the finger is (rests in the middle).
                      AnimatedPositioned(
                        duration: _active || reduce ? Duration.zero : const Duration(milliseconds: 420),
                        curve: const Cubic(0.22, 1, 0.36, 1),
                        left: dot.dx - 6,
                        top: dot.dy - 6,
                        child: AnimatedOpacity(
                          opacity: widget.enabled ? 1 : 0.25,
                          duration: const Duration(milliseconds: 200),
                          child: AnimatedScale(
                            scale: _active ? 1.6 : 1,
                            duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(color: K.white, shape: BoxShape.circle),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 18,
                        child: Text(
                          widget.enabled
                              ? (isMobile ? 'Move one finger · scroll with two' : 'Drag to move · click · scroll')
                              : widget.connecting
                              ? 'Connecting…'
                              : 'Not connected',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, color: K.muted),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGrid extends CustomPainter {
  const _DotGrid();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1AFFFFFF);
    for (var y = 22.0; y < size.height; y += 26) {
      for (var x = 22.0; x < size.width; x += 26) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
