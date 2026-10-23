import 'package:material_ui/material_ui.dart';

import '../core/host.dart';

/// Settings → Theme → Nothing: black, white and grey like Nothing's phones,
/// dot-matrix page titles, small uppercase mono labels, red for progress and
/// the logo's full stop, green only for "connected". A trial look (the
/// owner's call): Default stays the default, and this can be deleted with
/// its pref value (`look` = `nothing`).
///
/// The theme carries [NothingLook]; screens ask [isNothing].
@immutable
class NothingLook extends ThemeExtension<NothingLook> {
  const NothingLook({required this.on});

  final bool on;

  @override
  NothingLook copyWith({bool? on}) => NothingLook(on: on ?? this.on);

  @override
  NothingLook lerp(NothingLook? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Whether the Nothing look is on for this part of the app.
bool isNothing(BuildContext context) => Theme.of(context).extension<NothingLook>()?.on ?? false;

const nothingRed = Color(0xFFD71921);

/// Only for "connected" (red reads as "something's wrong").
const nothingGreen = Color(0xFF22C55E);

/// The look's colors: black with dark grey cards, or light grey with white ones.
ColorScheme nothingScheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final fg = dark ? Colors.white : Colors.black;
  final bg = dark ? Colors.black : const Color(0xFFEDEDED);
  final card = dark ? const Color(0xFF151515) : Colors.white;
  final raised = dark ? const Color(0xFF262626) : const Color(0xFFE2E2E2);
  final muted = dark ? const Color(0xFF8C8C8C) : const Color(0xFF6E6E6E);
  return ColorScheme(
    brightness: brightness,
    primary: fg,
    onPrimary: bg,
    primaryContainer: raised,
    onPrimaryContainer: fg,
    secondary: muted,
    onSecondary: bg,
    secondaryContainer: raised,
    onSecondaryContainer: fg,
    tertiary: nothingRed,
    onTertiary: Colors.white,
    tertiaryContainer: raised,
    onTertiaryContainer: fg,
    error: nothingRed,
    onError: Colors.white,
    errorContainer: dark ? const Color(0xFF3A1214) : const Color(0xFFFADADB),
    onErrorContainer: fg,
    surface: bg,
    onSurface: fg,
    onSurfaceVariant: muted,
    surfaceContainerLowest: bg,
    surfaceContainerLow: card,
    surfaceContainer: card,
    surfaceContainerHigh: dark ? const Color(0xFF1C1C1C) : const Color(0xFFF7F7F7),
    surfaceContainerHighest: raised,
    outline: dark ? const Color(0xFF3A3A3A) : const Color(0xFFC4C4C4),
    outlineVariant: dark ? const Color(0xFF262626) : const Color(0xFFDADADA),
    inverseSurface: fg,
    onInverseSurface: bg,
    inversePrimary: muted,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );
}

/// The Material theme, turned into the Nothing look: pill buttons, flat
/// cards, red progress and switches. (Its tab bar and side bar are its own,
/// in nothing_screens.dart.)
ThemeData nothingTheme(ThemeData base) {
  final scheme = base.colorScheme;
  const pill = StadiumBorder();
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: base.cardTheme.copyWith(color: scheme.surfaceContainer),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(shape: const WidgetStatePropertyAll(pill)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        shape: const WidgetStatePropertyAll(pill),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
      ),
    ),
    // ignore: deprecated_member_use
    progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false, color: nothingRed),
    switchTheme: SwitchThemeData(
      thumbIcon: const WidgetStatePropertyAll(null),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : scheme.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? nothingRed : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    extensions: [...base.extensions.values, const NothingLook(on: true)],
  );
}

/// The system's monospaced font, for the small uppercase labels.
String get _monoFamily => (Host.isIOS || Host.isMacOS)
    ? 'Menlo'
    : Host.isWindows
    ? 'Consolas'
    : 'monospace';

/// Section labels in the Nothing look: small, uppercase, mono, spaced out.
TextStyle nothingLabel(BuildContext context, {double size = 11.5}) => TextStyle(
  fontFamily: _monoFamily,
  fontFamilyFallback: const ['Menlo', 'Consolas', 'Roboto Mono', 'monospace'],
  fontSize: size,
  letterSpacing: 1.4,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

// ------------------------------------------------------------------ dot-matrix

/// A 5×7 dot font, like Nothing's Ndot. Letters are shown in capitals.
const _glyphs = <String, List<String>>{
  'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  'C': ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
  'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  'G': ['01111', '10000', '10000', '10011', '10001', '10001', '01111'],
  'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
  'I': ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
  'J': ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
  'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  'N': ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
  'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  'W': ['10001', '10001', '10001', '10101', '10101', '10101', '01010'],
  'X': ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
  'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  'Z': ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
  '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
  '%': ['11001', '11010', '00010', '00100', '01000', '01011', '10011'],
  ':': ['00000', '00100', '00100', '00000', '00100', '00100', '00000'],
  '.': ['00000', '00000', '00000', '00000', '00000', '00110', '00110'],
  ',': ['00000', '00000', '00000', '00000', '00110', '00100', '01000'],
  "'": ['00100', '00100', '01000', '00000', '00000', '00000', '00000'],
  '-': ['00000', '00000', '00000', '11111', '00000', '00000', '00000'],
  '/': ['00001', '00010', '00010', '00100', '01000', '01000', '10000'],
  '!': ['00100', '00100', '00100', '00100', '00100', '00000', '00100'],
  '?': ['01110', '10001', '00001', '00110', '00100', '00000', '00100'],
  '&': ['01100', '10010', '10100', '01000', '10101', '10010', '01101'],
  ' ': ['00000', '00000', '00000', '00000', '00000', '00000', '00000'],
};

/// Text drawn in dots ([dot] is the size of one dot cell). Shrinks to fit.
class DotText extends StatelessWidget {
  const DotText(this.text, {super.key, this.dot = 4, this.color});
  final String text;
  final double dot;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chars = text.toUpperCase().split('');
    final width = chars.length * 6 * dot - dot;
    return Semantics(
      label: text,
      header: true,
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: CustomPaint(
            size: Size(width, 7 * dot),
            painter: _DotTextPainter(chars, dot, color ?? Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _DotTextPainter extends CustomPainter {
  _DotTextPainter(this.chars, this.dot, this.color);
  final List<String> chars;
  final double dot;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var i = 0; i < chars.length; i++) {
      final glyph = _glyphs[chars[i]] ?? _glyphs[' ']!;
      for (var y = 0; y < 7; y++) {
        for (var x = 0; x < 5; x++) {
          if (glyph[y][x] == '1') {
            canvas.drawCircle(Offset((i * 6 + x + 0.5) * dot, (y + 0.5) * dot), dot * 0.42, paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DotTextPainter old) => old.chars.join() != chars.join() || old.dot != dot || old.color != color;
}

/// "sk." in dots: the Nothing look's logo, the full stop in red.
const _sk = ['......X...', '......X...', '.XXXX.X..X', 'X.....X.X.', '.XXX..XX..', '....X.X.X.', 'XXXX..X..X'];

class DotLogo extends StatelessWidget {
  const DotLogo({super.key, this.height = 28, this.color});

  /// The height of the letters (seven dots).
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sidekick',
    image: true,
    child: CustomPaint(
      size: Size(height / 7 * 12, height),
      painter: _DotLogoPainter(color ?? Theme.of(context).colorScheme.onSurface),
    ),
  );
}

class _DotLogoPainter extends CustomPainter {
  _DotLogoPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.height / 7;
    final paint = Paint()..color = color;
    for (var y = 0; y < 7; y++) {
      for (var x = 0; x < 10; x++) {
        if (_sk[y][x] == 'X') canvas.drawCircle(Offset((x + 0.5) * step, (y + 0.5) * step), step * 0.44, paint);
      }
    }
    canvas.drawCircle(Offset(11.5 * step, 6.5 * step), step * 0.5, Paint()..color = nothingRed);
  }

  @override
  bool shouldRepaint(_DotLogoPainter old) => old.color != color;
}

// ------------------------------------------------------------------ pieces

/// A label in the look's voice: small uppercase mono.
class NothingLabel extends StatelessWidget {
  const NothingLabel(this.text, {super.key, this.size = 11, this.color});
  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: nothingLabel(context, size: size).copyWith(color: color),
  );
}

/// A rounded card: dark grey on black, white on light grey.
class NothingTile extends StatelessWidget {
  const NothingTile({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.radius = 26});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: child,
  );
}

/// A pill button: solid (white on black, black on light) or outlined.
class NothingPill extends StatelessWidget {
  const NothingPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.solid = true,
    this.icon,
    this.height = 44,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool solid;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(
        Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (solid) {
      final filled = style.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? scheme.surfaceContainerHighest : scheme.onSurface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? scheme.onSurfaceVariant : scheme.surface,
        ),
      );
      return icon == null
          ? FilledButton(onPressed: onPressed, style: filled, child: text)
          : FilledButton.icon(onPressed: onPressed, style: filled, icon: Icon(icon, size: 17), label: text);
    }
    final outlined = style.copyWith(
      foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
      side: WidgetStatePropertyAll(BorderSide(color: scheme.outline, width: 1.2)),
    );
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: outlined, child: text)
        : OutlinedButton.icon(onPressed: onPressed, style: outlined, icon: Icon(icon, size: 17), label: text);
  }
}

/// A round icon button on the card color.
class NothingRound extends StatelessWidget {
  const NothingRound({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 42,
    this.outlined = false,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  /// A thin ring instead of the card color (on cards).
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: size * 0.45),
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: outlined ? Colors.transparent : scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
        disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        side: outlined ? BorderSide(color: scheme.outlineVariant, width: 1.2) : null,
      ),
    );
  }
}

/// A status: a small dot, green only for "connected", and a mono label.
class NothingStatus extends StatelessWidget {
  const NothingStatus(this.text, {super.key, required this.on, this.size = 11});
  final String text;
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? nothingGreen : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 8),
      Flexible(child: NothingLabel(text, size: size)),
    ],
  );
}
