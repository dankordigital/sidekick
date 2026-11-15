/// The design's icons (Lucide, as the owner's Figma and the emulator use
/// them: 24×24, 2 px round strokes), drawn from their SVG so the app shows
/// the very same shapes. `LucideIcon('devices')`.
library;

import 'package:material_ui/material_ui.dart';

/// SVG source per name, copied from design/emulator/emulator.src.html (`I`).
const lucide = <String, String>{
  'devices': '<path d="M18 8V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h8"/><path d="M10 19v-3.96 3.15"/><path d="M7 19h5"/><rect width="6" height="10" x="16" y="12" rx="2"/>',
  'chat': '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="M7.5 8.5h9M7.5 12h9M7.5 15.5h6"/>',
  'send': '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m17 8-5-5-5 5"/><path d="M12 3v12"/>',
  'remote': '<path d="m9 10 3-3 3 3"/><path d="M12 13V7"/><rect width="20" height="14" x="2" y="3" rx="2"/><path d="M12 17v4"/><path d="M8 21h8"/>',
  'settings': '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
  'file': '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M16 13H8M16 17H8M10 9H8"/>',
  'photo': '<rect width="18" height="18" x="3" y="3" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.09-3.09a2 2 0 0 0-2.82 0L6 21"/>',
  'link': '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
  'paste': '<rect width="8" height="4" x="8" y="2" rx="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><path d="M12 11h4M12 16h4M8 11h.01M8 16h.01"/>',
  'phone': '<rect width="14" height="20" x="5" y="2" rx="2"/><path d="M12 18h.01"/>',
  'tablet': '<rect width="16" height="20" x="4" y="2" rx="2"/><path d="M12 18h.01"/>',
  'laptop': '<path d="M20 16V7a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v9m16 0H4m16 0 1.28 2.55a1 1 0 0 1-.9 1.45H3.62a1 1 0 0 1-.9-1.45L4 16"/>',
  'monitor': '<rect width="20" height="14" x="2" y="3" rx="2"/><path d="M8 21h8M12 17v4"/>',
  'folder': '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
  'search': '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  'more': '<circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="19" cy="12" r="1.3" fill="currentColor"/><circle cx="5" cy="12" r="1.3" fill="currentColor"/>',
  'down': '<path d="m6 9 6 6 6-6"/>',
  'right': '<path d="m9 18 6-6-6-6"/>',
  'back': '<path d="m15 18-6-6 6-6"/>',
  'close': '<path d="M18 6 6 18M6 6l12 12"/>',
  'copy': '<rect width="14" height="14" x="8" y="8" rx="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
  'check': '<path d="M20 6 9 17l-5-5"/>',
  'plus': '<path d="M5 12h14M12 5v14"/>',
  'download': '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/><path d="M12 15V3"/>',
  'star': '<path d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"/>',
  'ping': '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
  'keyboard': '<path d="M10 8h.01M12 12h.01M14 8h.01M16 12h.01M18 8h.01M6 8h.01M7 16h10M8 12h.01"/><rect width="20" height="16" x="2" y="4" rx="2"/>',
  'lock': '<rect width="18" height="11" x="3" y="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  'wifi': '<path d="M12 20h.01M2 8.82a15 15 0 0 1 20 0M5 12.859a10 10 0 0 1 14 0M8.5 16.429a5 5 0 0 1 7 0"/>',
  'up': '<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>',
  'alert': '<circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/>',
  'refresh': '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
};

/// One design icon, [size] square, stroked in [color] (the text colour by
/// default).
class LucideIcon extends StatelessWidget {
  const LucideIcon(this.name, {super.key, this.size = 20, this.color, this.stroke = 2, this.semanticLabel});
  final String name;
  final double size;
  final Color? color;
  final double stroke;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color ?? Colors.white;
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LucidePainter(_shapes(name), c, stroke)),
    );
    return semanticLabel == null ? ExcludeSemantics(child: icon) : Semantics(label: semanticLabel, child: icon);
  }
}

final _cache = <String, Path>{};

Path _shapes(String name) => _cache[name] ??= _parse(lucide[name] ?? '');

class _LucidePainter extends CustomPainter {
  _LucidePainter(this.path, this.color, this.stroke);
  final Path path;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LucidePainter old) => old.path != path || old.color != color || old.stroke != stroke;
}

/// The SVG elements Lucide uses: path, rect, circle (and line, polyline).
Path _parse(String svg) {
  final out = Path();
  double a(String tag, String name, [double fallback = 0]) {
    final m = RegExp('\\b$name="([-\\d.]+)"').firstMatch(tag);
    return m == null ? fallback : double.parse(m.group(1)!);
  }

  for (final m in RegExp(r'<(\w+)([^>]*)/?>').allMatches(svg)) {
    final tag = m.group(2)!;
    switch (m.group(1)) {
      case 'path':
        final d = RegExp(r'\bd="([^"]*)"').firstMatch(tag)?.group(1);
        if (d != null) out.addPath(_pathData(d), Offset.zero);
      case 'rect':
        final rx = a(tag, 'rx');
        out.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(a(tag, 'x'), a(tag, 'y'), a(tag, 'width'), a(tag, 'height')),
            Radius.circular(rx == 0 ? a(tag, 'ry') : rx),
          ),
        );
      case 'circle':
        out.addOval(Rect.fromCircle(center: Offset(a(tag, 'cx'), a(tag, 'cy')), radius: a(tag, 'r')));
      case 'line':
        out
          ..moveTo(a(tag, 'x1'), a(tag, 'y1'))
          ..lineTo(a(tag, 'x2'), a(tag, 'y2'));
      case 'polyline':
        final p = RegExp(r'points="([^"]*)"').firstMatch(tag)?.group(1) ?? '';
        final n = RegExp(r'-?\d*\.?\d+').allMatches(p).map((e) => double.parse(e.group(0)!)).toList();
        for (var i = 0; i + 1 < n.length; i += 2) {
          i == 0 ? out.moveTo(n[i], n[i + 1]) : out.lineTo(n[i], n[i + 1]);
        }
    }
  }
  return out;
}

/// SVG path data → Path (M L H V C S Q T A Z, absolute and relative).
Path _pathData(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?')
      .allMatches(d)
      .map((m) => m.group(0)!)
      .toList();
  var i = 0;
  var cmd = 'M';
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  double? cx, cy; // last control point, for S / T
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(tokens[i++]);
  // Arc flags can be written together ("a2 2 0 011 1"): one digit each.
  double flag() {
    final t = tokens[i];
    if (t.length > 1 && (t.startsWith('0') || t.startsWith('1')) && !t.contains('.')) {
      tokens[i] = t.substring(1);
      return double.parse(t[0]);
    }
    i++;
    return double.parse(t);
  }

  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        cx = cy = null;
        cmd = rel ? 'l' : 'L';
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
        cx = cy = null;
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
        cx = cy = null;
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
        cx = cy = null;
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x2;
        cy = y2;
      case 'S':
        final x1 = cx == null ? x : 2 * x - cx, y1 = cy == null ? y : 2 * y - cy;
        final x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x2;
        cy = y2;
      case 'Q':
        final x1 = ox + n(), y1 = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        cx = x1;
        cy = y1;
      case 'T':
        final x1 = cx == null ? x : 2 * x - cx, y1 = cy == null ? y : 2 * y - cy;
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        cx = x1;
        cy = y1;
      case 'A':
        final rx = n(), ry = n(), rot = n();
        final large = flag() != 0, sweep = flag() != 0;
        x = ox + n();
        y = oy + n();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
        cx = cy = null;
      case 'Z':
        path.close();
        x = sx;
        y = sy;
        cx = cy = null;
      default:
        i++;
    }
  }
  return path;
}

/// The outline of [name] in its 24×24 box (for tests).
@visibleForTesting
Path lucidePath(String name) => _shapes(name);
