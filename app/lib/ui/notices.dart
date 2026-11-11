// Short notices for things that went well ("Sent 3 photos to Pixel 9",
// "Paired with MacBook Pro", "Received report.pdf"): they slide up at the
// bottom, a thin bar along their bottom edge empties, and they go by
// themselves (5 seconds, never more than 10). Hovering or touching one
// pauses it; swiping or ✕ closes it; a few in a row stack, the rest wait.
//
// Problems never come here: they're a pop-up with a Close button
// (showError in widgets.dart).
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'nothing.dart';

/// The longest a notice stays up.
const maxNoticeDuration = Duration(seconds: 10);

class NoticeData {
  NoticeData(
    this.message, {
    this.icon = Icons.check_circle_rounded,
    this.actionLabel,
    this.onAction,
    Duration duration = const Duration(seconds: 5),
  }) : duration = duration > maxNoticeDuration ? maxNoticeDuration : duration;

  final String message;
  final IconData icon;

  /// A button on the notice ("Show in folder", "Open"); tapping it closes
  /// the notice.
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final Key key = UniqueKey();
}

/// The notices on screen, and the ones waiting for room.
class NoticeCenter extends ChangeNotifier {
  NoticeCenter._();
  static final instance = NoticeCenter._();

  /// At most this many at once, newest at the bottom.
  static const maxShown = 3;

  final List<NoticeData> shown = [];
  final List<NoticeData> _waiting = [];

  void show(NoticeData notice) {
    (shown.length < maxShown ? shown : _waiting).add(notice);
    notifyListeners();
  }

  void dismiss(NoticeData notice) {
    if (!shown.remove(notice) && !_waiting.remove(notice)) return;
    while (shown.length < maxShown && _waiting.isNotEmpty) {
      shown.add(_waiting.removeAt(0));
    }
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    shown.clear();
    _waiting.clear();
    notifyListeners();
  }
}

/// Shows a short notice at the bottom of the screen (see the top of this
/// file). [icon] is a check mark unless said otherwise.
void showNotice(
  String message, {
  IconData icon = Icons.check_circle_rounded,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 5),
}) => NoticeCenter.instance.show(
  NoticeData(message, icon: icon, actionLabel: actionLabel, onAction: onAction, duration: duration),
);

/// Puts notices over [child] (MaterialApp's builder: over every screen).
class NoticeArea extends StatelessWidget {
  const NoticeArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Phones: above the tab bar (the shell is wide from 700 points).
    final bottom = media.size.width >= 700 ? 24.0 : media.viewPadding.bottom + 92;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom + media.viewInsets.bottom,
          child: ListenableBuilder(
            listenable: NoticeCenter.instance,
            builder: (context, _) => Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final n in NoticeCenter.instance.shown)
                      Padding(
                        key: n.key,
                        padding: const EdgeInsets.only(top: 8),
                        child: NoticeCard(notice: n, onGone: () => NoticeCenter.instance.dismiss(n)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NoticeCard extends StatefulWidget {
  const NoticeCard({super.key, required this.notice, required this.onGone});
  final NoticeData notice;
  final VoidCallback onGone;

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> with TickerProviderStateMixin {
  /// 1 → 0 over the notice's time: the bar along the bottom.
  late final _life = AnimationController(vsync: this, duration: widget.notice.duration, value: 1);

  /// 0 → 1 coming in, back to 0 going out.
  late final _appear = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  int _holds = 0;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _life.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) _leave();
    });
    _appear.forward();
    _life.reverse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: no sliding or fading (the bar still shows the time left).
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) _appear.value = _leaving ? 0 : 1;
  }

  @override
  void dispose() {
    _life.dispose();
    _appear.dispose();
    super.dispose();
  }

  void _hold() {
    if (_holds++ == 0) _life.stop();
  }

  void _release() {
    if (_holds > 0 && --_holds == 0 && !_leaving) _life.reverse();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _life.stop();
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      await _appear.animateBack(0, duration: const Duration(milliseconds: 180), curve: Curves.easeIn);
    }
    if (mounted) widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snack = theme.snackBarTheme;
    final background = snack.backgroundColor ?? scheme.inverseSurface;
    final text = (snack.contentTextStyle ?? theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: snack.contentTextStyle?.color ?? scheme.onInverseSurface,
    );
    // The Nothing look's inverse primary is a grey: its text color reads better.
    final accent = snack.actionTextColor ?? (isNothing(context) ? scheme.onInverseSurface : scheme.inversePrimary);
    final shape = snack.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final n = widget.notice;

    final card = Material(
      color: background,
      // The flat look: no shadow; the notice's own colors set it apart.
      elevation: 0,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: Row(
              children: [
                Icon(n.icon, color: accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(n.message, style: text),
                  ),
                ),
                if (n.actionLabel != null)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: accent),
                    onPressed: () {
                      n.onAction?.call();
                      _leave();
                    },
                    child: Text(n.actionLabel!),
                  ),
                Semantics(
                  container: true,
                  button: true,
                  label: 'Close',
                  onTap: _leave,
                  excludeSemantics: true,
                  child: IconButton(
                    onPressed: _leave,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: text.color?.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          // The time left: empties, then the notice goes.
          AnimatedBuilder(
            animation: _life,
            builder: (context, _) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: _life.value,
                child: Container(height: 3, color: accent.withValues(alpha: 0.85)),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: MouseRegion(
        onEnter: (_) => _hold(),
        onExit: (_) => _release(),
        child: Listener(
          onPointerDown: (_) => _hold(),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: Dismissible(
            key: ValueKey(n.key),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => widget.onGone(),
            child: AnimatedBuilder(
              animation: _appear,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_appear.value);
                return Opacity(
                  opacity: t,
                  // Read out from the start, not only once it has faded in.
                  alwaysIncludeSemantics: true,
                  child: Transform.translate(offset: Offset(0, reduce ? 0 : (1 - t) * 24), child: child),
                );
              },
              child: card,
            ),
          ),
        ),
      ),
    );
  }
}
