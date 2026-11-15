/// Sidekick 4.0's building blocks, copied from the design (the owner's
/// Figma "Foundations", as in design/emulator/emulator.src.html): page
/// titles, panels, labels, device tiles and pill buttons. Screens are built
/// from these so they look like the design, not like the old app recoloured.
library;

import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../core/models.dart';
import 'lucide.dart';

/// The design's colours.
abstract final class K {
  static const page = Color(0xFF121212);
  static const panel = Color(0xFF1C1C1C);
  static const raised = Color(0xFF262626);
  static const btn = Color(0xFF2E2E2E);
  static const text = Color(0xFFF2F2F2);
  static const muted = Color(0xFFA1A1A6);
  static const faint = Color(0xFF8A8A8F);
  static const white = Color(0xFFF0F0F0);
  static const onWhite = Color(0xFF141414);
  static const ok = Color(0xFF45D07E);
  static const amber = Color(0xFFFFC56B);
  static const amberBg = Color(0xFF2F2410);
  static const amberLine = Color(0x40FFC56B);
  static const amberText = Color(0xFFFFE2AD);
  static const blue = Color(0xFF5B9DFF);
  static const green = Color(0xFF4FCF86);
  static const orange = Color(0xFFFFB84D);
  static const red = Color(0xFFFF6B5E);
  static const line = Color(0x26FFFFFF);
  static const hair = Color(0x14FFFFFF);

  /// A device's colour in the design: phones blue, tablets amber,
  /// computers green (grey is for one never heard from, chosen by callers).
  static Color platformColor(DevicePlatform p) => switch (p) {
    DevicePlatform.ios || DevicePlatform.android => blue,
    DevicePlatform.macos || DevicePlatform.windows || DevicePlatform.linux => green,
    _ => orange,
  };
}

/// The design's device icons (line icons, like its Lucide set).
/// The design's device icon (Lucide), by name.
String deviceIconName(DevicePlatform p) => switch (p) {
  DevicePlatform.ios || DevicePlatform.android => 'phone',
  DevicePlatform.macos => 'laptop',
  DevicePlatform.windows || DevicePlatform.linux => 'monitor',
  _ => 'tablet',
};

IconData deviceIcon(DevicePlatform p) => switch (p) {
  DevicePlatform.ios || DevicePlatform.android => Icons.smartphone_outlined,
  DevicePlatform.macos => Icons.laptop_outlined,
  DevicePlatform.windows || DevicePlatform.linux => Icons.desktop_windows_outlined,
  _ => Icons.devices_other_outlined,
};

/// "Devices" in 30 px bold, with an optional button on the right.
class KTitle extends StatelessWidget {
  const KTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: K.text),
        ),
      ),
      ?action,
    ],
  );
}

/// The grey line under a title ("Your devices, a little closer.").
class KSub extends StatelessWidget {
  const KSub(this.text, {super.key, this.size = 14});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: size, color: K.muted, height: 1.35),
  );
}

/// A section label ("Favorites" with its star, "Paired").
class KLabel extends StatelessWidget {
  const KLabel(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
    child: Row(
      children: [
        if (icon != null) ...[
          icon == Icons.star_border_rounded || icon == Icons.star_rounded
              ? const LucideIcon('star', size: 22, color: K.text)
              : Icon(icon, size: 20, color: K.text),
          const SizedBox(width: 10),
        ],
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: K.muted),
        ),
      ],
    ),
  );
}

/// A #1c1c1c panel with 22 px corners that holds rows.
class KPanel extends StatelessWidget {
  const KPanel({super.key, required this.child, this.padding = EdgeInsets.zero, this.dashed = false});
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Nearby devices: a dashed outline instead of a fill.
  final bool dashed;

  @override
  Widget build(BuildContext context) => dashed
      ? CustomPaint(
          painter: _Dashes(),
          child: Padding(padding: padding, child: child),
        )
      : Container(
          padding: padding,
          decoration: BoxDecoration(color: K.panel, borderRadius: BorderRadius.circular(22)),
          child: child,
        );
}

class _Dashes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)).deflate(0.75));
    final paint = Paint()
      ..color = K.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A device's 48 px tile: its icon in its colour on #262626 (grey when it
/// can't be reached).
class KDeviceTile extends StatelessWidget {
  const KDeviceTile({super.key, required this.platform, required this.color, this.size = 48, this.background});
  final DevicePlatform platform;
  final Color color;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: background ?? K.raised, borderRadius: BorderRadius.circular(size * 0.3)),
    child: Center(
      child: LucideIcon(deviceIconName(platform), size: size * 0.46, color: color),
    ),
  );
}

/// A device row as the design draws it: a 48 px tile, the name and a
/// status line, one button on the right. The whole row is the tap target.
class KRow extends StatefulWidget {
  const KRow({
    super.key,
    required this.platform,
    required this.color,
    required this.name,
    required this.status,
    required this.statusColor,
    required this.action,
    this.onTap,
    this.onHold,
    this.tileBackground,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });
  final DevicePlatform platform;
  final Color color;
  final String name;
  final String status;
  final Color statusColor;
  final Widget action;
  final VoidCallback? onTap;
  final VoidCallback? onHold;
  final Color? tileBackground;
  final EdgeInsetsGeometry padding;

  @override
  State<KRow> createState() => _KRowState();
}

class _KRowState extends State<KRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onTap,
    onLongPress: widget.onHold,
    onSecondaryTap: widget.onHold,
    onTapDown: (_) => setState(() => _down = true),
    onTapUp: (_) => setState(() => _down = false),
    onTapCancel: () => setState(() => _down = false),
    child: AnimatedScale(
      scale: _down ? 0.98 : 1,
      duration: Duration(milliseconds: _down ? 90 : 300),
      curve: _down ? Curves.easeOut : const Cubic(0.34, 1.56, 0.64, 1),
      child: Padding(
        padding: widget.padding,
        child: Row(
          children: [
            KDeviceTile(platform: widget.platform, color: widget.color, background: widget.tileBackground),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: K.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: widget.statusColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            widget.action,
          ],
        ),
      ),
    ),
  );
}

enum KPillStyle { white, dark, outline, amber }

/// The design's pill buttons: white (the main action), dark, outlined, amber.
/// They press in with a springy release.
class KPill extends StatefulWidget {
  const KPill(
    this.label, {
    super.key,
    required this.onPressed,
    this.style = KPillStyle.white,
    this.icon,
    this.small = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final KPillStyle style;
  final IconData? icon;
  final bool small;

  @override
  State<KPill> createState() => _KPillState();
}

class _KPillState extends State<KPill> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (widget.style) {
      KPillStyle.white => (K.white, K.onWhite, null),
      KPillStyle.dark => (K.btn, K.text, null),
      KPillStyle.outline => (Colors.transparent, K.text, K.line),
      KPillStyle.amber => (K.amber, const Color(0xFF241800), null),
    };
    final enabled = widget.onPressed != null;
    final h = widget.small ? 34.0 : 44.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: Duration(milliseconds: _down ? 90 : 320),
          curve: _down ? Curves.easeOut : const Cubic(0.34, 1.56, 0.64, 1),
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.4,
            duration: const Duration(milliseconds: 150),
            child: Container(
              height: h,
              padding: EdgeInsets.symmetric(horizontal: widget.small ? 13 : 20),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(h / 2),
                border: border == null ? null : Border.all(color: border),
              ),
              // Stretched (full width, or beside another in a row): the
              // label sits in the middle.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: fg), const SizedBox(width: 8)],
                  Text(
                    widget.label,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w500, fontSize: widget.small ? 13.5 : 15),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a hold (or right-click) shows: a title, ✕ in the corner, and one
/// big row per action (null greys it out). A sheet on phones, flicked down
/// or ✕ to close; a dialog on computers.
Future<void> showActions(
  BuildContext context, {
  required String title,
  required List<(String, IconData, VoidCallback?)> options,
  String? footnote,
}) async {
  Widget body(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: K.text),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(backgroundColor: K.raised, minimumSize: const Size(44, 44)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (label, icon, onTap) in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: K.raised,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          onTap();
                        },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: onTap == null ? K.faint : K.text),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: onTap == null ? K.faint : K.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (footnote != null) Text(footnote, style: const TextStyle(fontSize: 12, color: K.faint)),
        ],
      ),
    ),
  );
  final phone = MediaQuery.sizeOf(context).width < 700;
  if (phone) {
    await showModalBottomSheet<void>(context: context, showDragHandle: true, backgroundColor: K.panel, builder: body);
  } else {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: K.panel,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(padding: const EdgeInsets.only(top: 16), child: body(context)),
        ),
      ),
    );
  }
}

/// The device a tab is about, as a panel (design: Remote, Chat): its tile,
/// name and how it's reached, and a chevron that picks another one.
class KDevicePicker extends StatelessWidget {
  const KDevicePicker({super.key, required this.state, required this.device, required this.onPick, this.only});
  final AppState state;
  final PairedDevice device;
  final ValueChanged<PairedDevice> onPick;

  /// Which devices the list offers (all paired ones when null).
  final bool Function(PairedDevice d)? only;

  List<PairedDevice> get _choices => [
    for (final d in state.paired)
      if (only?.call(d) ?? true) d,
  ];

  @override
  Widget build(BuildContext context) {
    final how = state.connectionLabel(device.id);
    final online = state.isOnline(device.id);
    final many = state.paired.length > 1;
    return Semantics(
      button: many,
      label: '${device.name}${many ? '. Pick another device' : ''}',
      excludeSemantics: true,
      child: Material(
        color: K.panel,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: many ? () => pickDevice(context) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
            child: Row(
              children: [
                KDeviceTile(platform: device.platform, color: K.platformColor(device.platform)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, color: K.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        online ? '${how ?? 'Connected'} · encrypted' : 'Not reachable',
                        style: TextStyle(fontSize: 12.5, color: online ? K.ok : K.faint),
                      ),
                    ],
                  ),
                ),
                if (many) const Icon(Icons.keyboard_arrow_down_rounded, size: 26, color: K.text),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The list of devices to pick from (also for "Choose a computer").
  Future<void> pickDevice(BuildContext context) => showActions(
    context,
    title: 'Choose a device',
    options: [
      for (final d in _choices) (d.id == device.id ? '${d.name}  ✓' : d.name, deviceIcon(d.platform), () => onPick(d)),
    ],
  );
}
