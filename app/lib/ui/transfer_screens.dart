import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../core/history.dart';
import '../core/server.dart';
import '../platform/sound.dart';
import 'kit.dart';
import 'lucide.dart';
import 'widgets.dart';

// ------------------------------------------------------------------ sender

/// Shows [send] full screen: waiting for the other device to accept, then
/// the progress, then it closes by itself.
Future<void> showSendingScreen(BuildContext context, OutgoingSend send, {AppState? state}) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => SendingScreen(send: send, state: state),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(curved), child: child),
          );
        },
      ),
    );

/// Closes the screen or dialog [context] is in: this one, even when
/// something else (a dialog, a snackbar's route) has opened on top of it.
/// Popping "whatever's on top" closed the wrong thing and left the screen
/// stuck with its Close button spent.
void closeRoute(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  final navigator = Navigator.of(context);
  if (route.isCurrent) {
    navigator.pop();
  } else {
    navigator.removeRoute(route);
  }
}

class SendingScreen extends StatefulWidget {
  const SendingScreen({super.key, required this.send, this.state});
  final OutgoingSend send;

  /// For how the device is reached ("Same Wi-Fi"); optional.
  final AppState? state;

  @override
  State<SendingScreen> createState() => _SendingScreenState();
}

class _SendingScreenState extends State<SendingScreen> {
  OutgoingSend get send => widget.send;
  Timer? _close;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    send.watchers++;
    send.addListener(_changed);
  }

  @override
  void dispose() {
    send.watchers--;
    send.removeListener(_changed);
    _close?.cancel();
    super.dispose();
  }

  void _changed() {
    if (send.cancelled) return _leave();
    // Finished: let the result sink in, then back to the app.
    final wait = switch (send.phase) {
      SendPhase.done => const Duration(milliseconds: 1500),
      SendPhase.declined || SendPhase.noAnswer => const Duration(milliseconds: 2800),
      _ => null,
    };
    if (wait != null) _close ??= Timer(wait, _leave);
    setState(() {});
  }

  void _leave() {
    if (_closing || !mounted) return;
    _closing = true;
    closeRoute(context);
  }

  /// Cancel always closes the screen, even if the send moved on meanwhile.
  void _cancel() {
    unawaited(send.cancel());
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final d = send.device;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final how = _state?.connectionLabel(d.id);
    final hiding = send.phase == SendPhase.sending && !send.reconnecting;
    return Scaffold(
      backgroundColor: K.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // ← hides it (the send carries on); "Sending" beside it.
                Row(
                  children: [
                    IconButton(
                      tooltip: hiding ? 'Hide' : 'Back',
                      onPressed: hiding ? _leave : _action.$2,
                      icon: const Icon(Icons.chevron_left_rounded, size: 28),
                      style: IconButton.styleFrom(backgroundColor: K.btn, minimumSize: const Size(48, 48)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: KTitle(_title)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    KDeviceTile(platform: d.platform, color: K.platformColor(d.platform)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: K.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            send.reconnecting ? 'Reconnecting…' : '${how ?? 'Connected'} · encrypted',
                            style: TextStyle(fontSize: 13, color: send.reconnecting ? K.amber : K.ok),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Center(
                  child: SizedBox.square(
                    dimension: 220,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: send.phase == SendPhase.done ? 1 : send.fraction),
                      duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
                      curve: const Cubic(0.22, 1, 0.36, 1),
                      builder: (context, value, _) => CustomPaint(
                        painter: _Arc(value: value, color: _ringColor, track: K.btn),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
                            child: _middle(value),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: Text(
                    _line,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: K.text, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
                const SizedBox(height: 18),
                KPanel(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Column(children: [for (var i = 0; i < send.names.length; i++) _file(i)]),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: KPill(
                    _action.$1,
                    style: send.phase == SendPhase.failed ? KPillStyle.white : KPillStyle.outline,
                    onPressed: _action.$2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppState? get _state => widget.state;

  String get _title => switch (send.phase) {
    SendPhase.connecting || SendPhase.waiting || SendPhase.sending => 'Sending',
    SendPhase.done => 'Sent',
    SendPhase.declined => 'Declined',
    SendPhase.noAnswer => 'No answer',
    SendPhase.failed => "Couldn't send",
  };

  Color get _ringColor => switch (send.phase) {
    SendPhase.done => K.ok,
    SendPhase.declined || SendPhase.noAnswer || SendPhase.failed => K.red,
    _ when send.reconnecting => K.amber,
    _ => K.white,
  };

  /// The ring's middle: the percent and time left, or what's happening.
  Widget _middle(double value) {
    final d = send.device;
    final (String big, String small) = switch (send.phase) {
      SendPhase.connecting => ('…', 'Reaching ${d.name}'),
      SendPhase.waiting => ('Waiting', 'Ask them to tap Accept'),
      SendPhase.sending when send.reconnecting => ('${(value * 100).floor()}%', 'Reconnecting…'),
      SendPhase.sending => (
        '${(value * 100).floor()}%',
        switch (send.remaining) {
          final r? when r.inSeconds > 0 => _aboutLeft(r),
          _ => 'Sending…',
        },
      ),
      SendPhase.done => ('✓', 'On ${d.name}'),
      SendPhase.declined => ('✕', 'Nothing was sent'),
      SendPhase.noAnswer => ('✕', 'Nobody accepted'),
      SendPhase.failed => ('!', 'Something went wrong'),
    };
    return Padding(
      key: ValueKey((send.phase, send.reconnecting, big.endsWith('%'))),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (switch (big) {
                '✓' => Icons.check_rounded,
                '✕' => Icons.close_rounded,
                '!' => Icons.priority_high_rounded,
                _ => null,
              }
              case final icon?)
            Icon(icon, size: 52, color: _ringColor)
          else
            Text(
              big,
              style: TextStyle(
                fontSize: big.length > 4 ? 26 : 38,
                fontWeight: FontWeight.w700,
                color: K.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            small,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: K.muted),
          ),
        ],
      ),
    );
  }

  /// "About 2 seconds left", "About 3 minutes left" (the design's words).
  static String _aboutLeft(Duration r) {
    if (r.inSeconds < 60) return 'About ${r.inSeconds} ${r.inSeconds == 1 ? 'second' : 'seconds'} left';
    final m = (r.inSeconds / 60).ceil();
    if (m < 60) return 'About $m ${m == 1 ? 'minute' : 'minutes'} left';
    return 'About ${r.inHours} h ${r.inMinutes.remainder(60)} min left';
  }

  /// "30.5 of 47.7 MB · 12 MB/s", or what happened.
  String get _line => switch (send.phase) {
    SendPhase.sending => [
      '${formatBytes(send.done)} of ${formatBytes(send.total)}',
      if (send.speed case final s? when !send.reconnecting) '${formatBytes(s.round())}/s',
    ].join(' · '),
    SendPhase.failed => send.error ?? 'Something went wrong',
    SendPhase.done => '${formatBytes(send.total)} sent',
    SendPhase.declined => '${send.device.name} declined',
    SendPhase.noAnswer => 'No answer in time',
    _ => formatBytes(send.total),
  };

  /// One file: its name, how much of it is there, a thin bar.
  Widget _file(int i) {
    final size = i < send.sizes.length ? send.sizes[i] : 0;
    final before = send.sizes.take(i).fold(0, (a, b) => a + b);
    final done = send.phase == SendPhase.done
        ? size
        : send.sizes.length == send.names.length
        ? (send.done - before).clamp(0, size)
        : (i < send.current ? size : 0);
    final finished = send.phase == SendPhase.done || (size > 0 ? done >= size : i < send.current);
    final fraction = size > 0 ? done / size : (finished ? 1.0 : 0.0);
    final detail = finished
        ? '${formatBytes(size)} · sent ✓'
        : done > 0
        ? '${formatBytes(done)} of ${formatBytes(size)}'
        : formatBytes(size);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            send.names[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: K.text),
          ),
          const SizedBox(height: 8),
          Text(detail, style: const TextStyle(fontSize: 12.5, color: K.muted)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(value: fraction, minHeight: 3, color: K.white, backgroundColor: K.btn),
          ),
        ],
      ),
    );
  }

  (String, VoidCallback) get _action => switch (send.phase) {
    SendPhase.connecting || SendPhase.waiting => ('Cancel', _cancel),
    SendPhase.sending => ('Stop', _cancel),
    _ => ('Close', _leave),
  };
}

/// A round progress ring.
class _Arc extends CustomPainter {
  _Arc({required this.value, required this.color, required this.track});
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(5), 0, 2 * math.pi, false, stroke..color = track);
    canvas.drawArc(rect.deflate(5), -math.pi / 2, 2 * math.pi * value, false, stroke..color = color);
  }

  @override
  bool shouldRepaint(_Arc old) => old.value != value || old.color != color || old.track != track;
}

// ------------------------------------------------------------------ receiver

/// A request to send this device files (design: `Incoming files.png`): an
/// amber card saying who and how much, the files, where they'll go, Always
/// accept, then Decline / Accept side by side. A sheet from the bottom on
/// phones (Accept right under the thumb), a card in the middle on computers.
Future<void> showIncomingOffer(BuildContext context, TransferOffer offer, {AppState? state, bool sounds = false}) {
  final sheet = MediaQuery.sizeOf(context).width < 700;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Incoming files',
    barrierColor: Colors.black54,
    transitionDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 520),
    pageBuilder: (_, _, _) => _IncomingOffer(offer: offer, state: state, sounds: sounds, sheet: sheet),
    transitionBuilder: (_, animation, _, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final rise = CurvedAnimation(parent: animation, curve: const Cubic(0.22, 1, 0.36, 1));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween(begin: Offset(0, sheet ? 0.35 : 0.06), end: Offset.zero).animate(rise),
          child: sheet ? child : ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(rise), child: child),
        ),
      );
    },
  );
}

class _IncomingOffer extends StatefulWidget {
  const _IncomingOffer({required this.offer, required this.state, required this.sounds, required this.sheet});
  final TransferOffer offer;

  /// For "Always accept from …" (none in the screenshot tools).
  final AppState? state;

  /// Play the accept/decline sounds.
  final bool sounds;

  /// Phones: a sheet at the bottom.
  final bool sheet;

  @override
  State<_IncomingOffer> createState() => _IncomingOfferState();
}

enum _Stage { asking, receiving, done, gone }

class _IncomingOfferState extends State<_IncomingOffer> with SingleTickerProviderStateMixin {
  TransferOffer get offer => widget.offer;

  /// Time left to answer, running down along the amber card's bottom edge.
  late final AnimationController _countdown = AnimationController(vsync: this, duration: SidekickServer.offerTimeout)
    ..reverse(from: 1);

  _Stage _stage = _Stage.asking;
  int _received = 0;
  StreamSubscription<int>? _progress;
  bool _closing = false;

  /// "Always accept from …", ticked: Accept makes the device a favourite.
  late bool _always = widget.state?.alwaysAccept.contains(offer.from.id) ?? false;

  @override
  void initState() {
    super.initState();
    offer.answer.then((answer) {
      if (!mounted || _stage != _Stage.asking) return;
      switch (answer) {
        // Answered from the notification: follow along.
        case OfferAnswer.accepted:
          _receive();
        case OfferAnswer.declined:
          _leave();
        // The sender gave up, or time ran out.
        case OfferAnswer.cancelled || OfferAnswer.timedOut:
          setState(() => _stage = _Stage.gone);
          Timer(const Duration(milliseconds: 1400), _leave);
      }
    });
  }

  @override
  void dispose() {
    _countdown.dispose();
    _progress?.cancel();
    super.dispose();
  }

  void _leave() {
    if (_closing || !mounted) return;
    _closing = true;
    closeRoute(context);
  }

  void _accept() {
    if (_always) widget.state?.setAlwaysAccept(offer.from.id, true);
    offer.accept();
    if (widget.sounds) unawaited(playAcceptSound());
    _receive();
  }

  void _receive() {
    if (_stage != _Stage.asking) return;
    _countdown.stop();
    setState(() => _stage = _Stage.receiving);
    _progress = offer.progress.listen(
      (bytes) => setState(() => _received = bytes),
      onDone: () {
        if (!mounted) return;
        if (offer.stopped) {
          setState(() => _stage = _Stage.gone);
          Timer(const Duration(milliseconds: 1400), _leave);
          return;
        }
        setState(() => _stage = _Stage.done);
        Timer(const Duration(milliseconds: 1500), _leave);
      },
    );
  }

  void _decline() {
    offer.decline();
    if (widget.sounds) unawaited(playDeclineSound());
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final files = offer.files;
    final what = files.length == 1 ? files.first.name : '${files.length} files';
    final total = offer.totalBytes;
    final from = offer.from.name;
    final how = widget.state?.connectionLabel(offer.from.id);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final phone = Platform.isIOS || Platform.isAndroid;
    final (title, titleColor) = switch (_stage) {
      _Stage.asking => ('$from wants to send you $what', K.amber),
      _Stage.receiving => ('Receiving from $from…', K.text),
      _Stage.done => ('All here', K.ok),
      _Stage.gone => ('$from stopped sending', K.muted),
    };
    final card = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Who and how much, in amber: the one thing that needs you.
        AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _stage == _Stage.asking ? K.amberBg : K.raised,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _stage == _Stage.asking ? K.amberLine : Colors.transparent),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: K.panel, borderRadius: BorderRadius.circular(14)),
                      child: Center(
                        child: LucideIcon(
                          switch (_stage) {
                            _Stage.done => 'check',
                            _Stage.gone => 'close',
                            _ => deviceIconName(offer.from.platform),
                          },
                          size: 22,
                          color: _stage == _Stage.done ? K.ok : K.platformColor(offer.from.platform),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
                            layoutBuilder: (current, previous) =>
                                Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                            child: Text(
                              title,
                              key: ValueKey(_stage),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.3,
                                fontWeight: FontWeight.w400,
                                color: titleColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              if (total > 0) formatBytes(total),
                              how ?? 'encrypted',
                              if (how != null) 'encrypted',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 13,
                              color: _stage == _Stage.asking ? K.amberText.withValues(alpha: 0.8) : K.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_stage == _Stage.asking)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _countdown,
                    builder: (_, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _countdown.value,
                      child: Container(height: 2, color: K.amber.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final f in files.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                LucideIcon(
                  switch (historyKindOf(f.name)) {
                    HistoryKind.photo || HistoryKind.video => 'photo',
                    _ => 'file',
                  },
                  size: 22,
                  color: K.text,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: K.text),
                  ),
                ),
                const SizedBox(width: 10),
                Text(formatBytes(f.size), style: const TextStyle(fontSize: 12.5, color: K.muted)),
              ],
            ),
          ),
        if (files.length > 5)
          Padding(padding: const EdgeInsets.only(top: 2, bottom: 6), child: KSub('and ${files.length - 5} more')),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
          curve: const Cubic(0.22, 1, 0.36, 1),
          alignment: Alignment.topCenter,
          child: switch (_stage) {
            _Stage.asking => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KSub(
                  phone
                      ? 'Photos and videos go straight to Photos. The rest goes to Files › Sidekick.'
                      : 'They go to your Sidekick folder.',
                ),
                if (widget.state != null) ...[
                  const SizedBox(height: 8),
                  // The whole line is the tick box.
                  Semantics(
                    checked: _always,
                    button: true,
                    label: 'Always accept from $from',
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _always = !_always),
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            AnimatedSwitcher(
                              duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
                              child: Icon(
                                _always ? Icons.check_circle_rounded : Icons.circle_outlined,
                                key: ValueKey(_always),
                                size: 22,
                                color: _always ? K.amber : K.muted,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Always accept from $from',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: K.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: KPill('Decline', style: KPillStyle.outline, onPressed: _decline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KPill('Accept', style: KPillStyle.amber, onPressed: _accept),
                    ),
                  ],
                ),
              ],
            ),
            _Stage.receiving => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: total > 0 ? (_received / total).clamp(0.0, 1.0) : 0),
                  duration: const Duration(milliseconds: 250),
                  builder: (_, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: total > 0 ? value : null,
                      minHeight: 6,
                      color: K.white,
                      backgroundColor: K.btn,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${formatBytes(_received)} of ${formatBytes(total)}',
                  style: const TextStyle(fontSize: 13, color: K.muted, fontFeatures: [FontFeature.tabularFigures()]),
                ),
                const SizedBox(height: 16),
                KPill('Hide', style: KPillStyle.outline, onPressed: _leave),
              ],
            ),
            _ => const SizedBox(height: 8, width: double.infinity),
          },
        ),
      ],
    );
    final body = Material(
      color: K.panel,
      borderRadius: widget.sheet ? const BorderRadius.vertical(top: Radius.circular(30)) : BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, widget.sheet ? 12 : 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.sheet)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(color: K.faint, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              card,
            ],
          ),
        ),
      ),
    );
    if (widget.sheet) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
          child: body,
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: body),
      ),
    );
  }
}
