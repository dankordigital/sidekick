import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart' show MethodChannel, StandardMessageCodec;
import 'package:material_ui/material_ui.dart';

import 'widgets.dart' show appleOsMajor;
import '../core/host.dart';

/// Settings → Theme → Liquid Glass (iOS and macOS 26+): the same app, with
/// frosted, translucent surfaces over a soft backdrop in the theme's colors,
/// like Apple's own look since 26. Material stays the default everywhere.
///
/// The theme carries [GlassLook]; screens ask [isGlass] and wrap the bars and
/// panels that float over content in a [GlassPanel].
@immutable
class GlassLook extends ThemeExtension<GlassLook> {
  const GlassLook({required this.on});

  final bool on;

  @override
  GlassLook copyWith({bool? on}) => GlassLook(on: on ?? this.on);

  @override
  GlassLook lerp(GlassLook? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// Whether the Liquid Glass look is on for this part of the app.
bool isGlass(BuildContext context) => Theme.of(context).extension<GlassLook>()?.on ?? false;

/// The tint of a glass surface: the theme's surface, mostly see-through.
Color glassTint(ColorScheme scheme, [double opacity = 0.5]) => scheme.surface.withValues(alpha: opacity);

/// The thin bright rim along a glass edge.
Color glassRim(ColorScheme scheme) =>
    Colors.white.withValues(alpha: scheme.brightness == Brightness.dark ? 0.14 : 0.55);

/// The real thing: Apple's Liquid Glass views (UIGlassEffect on iOS 26,
/// as a platform view; on the Mac Sidekick draws its own). Elsewhere (and in the
/// screenshot tool) [GlassPanel] draws a frosted look of its own.
bool get nativeGlass => Host.isIOS && (appleOsMajor ?? 0) >= 26;

/// Frosted glass: blurs what's behind it, tints it and draws a bright rim.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 24,
    this.opacity = 0.5,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(radius);
    if (nativeGlass) {
      // Apple's own Liquid Glass, drawn by the system under our widgets.
      final params = {'radius': radius, 'dark': scheme.brightness == Brightness.dark};
      final glass = UiKitView(
        viewType: 'sidekick/glass',
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      );
      return Stack(
        children: [
          // Keyed by the look: the native view is rebuilt when dark mode flips.
          Positioned.fill(
            child: IgnorePointer(key: ValueKey(params['dark']), child: glass),
          ),
          Padding(padding: padding, child: child),
        ],
      );
    }
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: glassRim(scheme)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Lighter at the top-left, as if lit from above.
          colors: [
            Color.lerp(glassTint(scheme, opacity), Colors.white, scheme.brightness == Brightness.dark ? 0.04 : 0.18)!,
            glassTint(scheme, opacity),
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    return ClipRRect(
      borderRadius: shape,
      child: blur > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: panel,
            )
          : panel,
    );
  }
}

/// What glass sits on: soft blobs of the theme's colors over its surface,
/// so the translucent panels have something to show.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    RadialGradient blob(Alignment at, Color color, double radius) => RadialGradient(
      center: at,
      radius: radius,
      colors: [
        color.withValues(alpha: dark ? 0.5 : 0.85),
        color.withValues(alpha: 0),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: blob(const Alignment(-0.9, -0.8), dark ? scheme.primary : scheme.primaryContainer, 1.1),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: blob(const Alignment(1, -0.1), scheme.tertiaryContainer, 0.9)),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: blob(const Alignment(-0.2, 1.1), scheme.secondaryContainer, 1.0)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A glass fill for buttons and other small controls:
/// tints it with [color] (the control's own color, so a primary button stays
/// in the theme's hue), lights it from the top and draws a bright rim.
class GlassFill extends StatelessWidget {
  const GlassFill({super.key, required this.color, this.child});

  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    // No live blur: behind a control the backdrop's soft blobs look the same
    // blurred or not, and a BackdropFilter per button made every screen with
    // a few of them slow to draw. The tint, top light and rim make the glass.
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: glassRim(scheme))),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, dark ? 0.08 : 0.22)!, color],
        ),
      ),
      child: child,
    );
  }
}

/// A button style whose background is [GlassFill] in [tint] (dimmed when
/// disabled), with [foreground] text and icons.
ButtonStyle _glassButton(ButtonStyle? base, ColorScheme scheme, Color tint, Color foreground) {
  return (base ?? const ButtonStyle()).copyWith(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? scheme.onSurface.withValues(alpha: 0.38) : foreground,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? scheme.onSurface.withValues(alpha: 0.38) : foreground,
    ),
    backgroundBuilder: (context, states, child) =>
        GlassFill(color: states.contains(WidgetState.disabled) ? glassTint(scheme, 0.25) : tint, child: child),
  );
}

/// Turns a Material theme into its Liquid Glass version: see-through
/// backgrounds (the [GlassBackdrop] shows through), translucent cards with a
/// bright rim, frosted dialogs, sheets and menus, and glass buttons, chips,
/// switches, fields and selections, each tinted in its own color.
ThemeData glassTheme(ThemeData base) {
  final scheme = base.colorScheme;
  final dark = scheme.brightness == Brightness.dark;
  final rim = BorderSide(color: glassRim(scheme));
  final selected = scheme.primary.withValues(alpha: dark ? 0.32 : 0.22);
  bool on(Set<WidgetState> states) => states.contains(WidgetState.selected);
  final glassMenu = MenuStyle(
    backgroundColor: WidgetStatePropertyAll(glassTint(scheme, 0.9)),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: rim)),
  );
  OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
  return base.copyWith(
    extensions: [...base.extensions.values, const GlassLook(on: true)],
    scaffoldBackgroundColor: Colors.transparent,
    cardTheme: base.cardTheme.copyWith(
      color: glassTint(scheme, 0.55),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: rim),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: glassTint(scheme, 0.86),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32), side: rim),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: glassTint(scheme, 0.86),
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: glassTint(scheme, 0.9),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: rim),
    ),
    menuTheme: MenuThemeData(style: glassMenu),
    dropdownMenuTheme: base.dropdownMenuTheme.copyWith(menuStyle: glassMenu),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: selected,
      indicatorShape: StadiumBorder(side: rim),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: Colors.transparent,
      indicatorColor: selected,
      indicatorShape: StadiumBorder(side: rim),
    ),
    appBarTheme: base.appBarTheme.copyWith(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
    // Buttons: glass in their own colors.
    filledButtonTheme: FilledButtonThemeData(
      style: _glassButton(
        base.filledButtonTheme.style,
        scheme,
        scheme.primary.withValues(alpha: dark ? 0.62 : 0.72),
        scheme.onPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _glassButton(base.elevatedButtonTheme.style, scheme, glassTint(scheme, 0.5), scheme.primary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _glassButton(base.outlinedButtonTheme.style, scheme, glassTint(scheme, 0.32), scheme.primary),
    ),
    textButtonTheme: TextButtonThemeData(
      style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        overlayColor: WidgetStatePropertyAll(scheme.primary.withValues(alpha: 0.12)),
      ),
    ),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.7),
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: StadiumBorder(side: rim),
    ),
    // Selections: glass segments and chips, the chosen one in the theme's hue.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => on(s) ? selected : glassTint(scheme, 0.32)),
        foregroundColor: WidgetStateProperty.resolveWith((s) => on(s) ? scheme.primary : scheme.onSurface),
        side: WidgetStatePropertyAll(rim),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      color: WidgetStateProperty.resolveWith((s) => on(s) ? selected : glassTint(scheme, 0.36)),
      side: rim,
      shape: StadiumBorder(side: rim),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    ),
    listTileTheme: base.listTileTheme.copyWith(selectedTileColor: selected, selectedColor: scheme.primary),
    switchTheme: base.switchTheme.copyWith(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => on(s) ? scheme.primary.withValues(alpha: 0.75) : glassTint(scheme, 0.4),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => on(s) ? glassRim(scheme) : scheme.outlineVariant),
      thumbColor: WidgetStateProperty.resolveWith((s) => on(s) ? Colors.white : scheme.outline),
    ),
    checkboxTheme: base.checkboxTheme.copyWith(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => on(s) ? scheme.primary.withValues(alpha: 0.8) : glassTint(scheme, 0.4),
      ),
    ),
    radioTheme: base.radioTheme.copyWith(
      fillColor: WidgetStateProperty.resolveWith((s) => on(s) ? scheme.primary : scheme.onSurfaceVariant),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: scheme.primary.withValues(alpha: 0.8),
      inactiveTrackColor: glassTint(scheme, 0.45),
    ),
    progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
      linearTrackColor: glassTint(scheme, 0.45),
      circularTrackColor: glassTint(scheme, 0.3),
    ),
    // Fields: frosted, with a bright rim, and the theme's color when focused.
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: glassTint(scheme, 0.4),
      border: field(glassRim(scheme)),
      enabledBorder: field(glassRim(scheme)),
      focusedBorder: field(scheme.primary.withValues(alpha: 0.8), 2),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      backgroundColor: glassTint(scheme, 0.92),
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      actionTextColor: scheme.primary,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: rim),
    ),
    tooltipTheme: base.tooltipTheme.copyWith(
      decoration: ShapeDecoration(
        color: glassTint(scheme, 0.92),
        shape: StadiumBorder(side: rim),
      ),
      textStyle: base.textTheme.bodySmall?.copyWith(color: scheme.onSurface),
    ),
    badgeTheme: base.badgeTheme.copyWith(backgroundColor: scheme.primary.withValues(alpha: 0.85)),
    dividerTheme: base.dividerTheme.copyWith(color: glassRim(scheme)),
    drawerTheme: base.drawerTheme.copyWith(
      backgroundColor: glassTint(scheme, 0.86),
      surfaceTintColor: Colors.transparent,
    ),
  );
}

/// Liquid Glass on an iPhone (iOS 26+): Apple's own tab bar, swipeable,
/// instead of Flutter's. [symbols] are SF Symbols names, one per tab.
class NativeTabBar extends StatefulWidget {
  const NativeTabBar({
    super.key,
    required this.labels,
    required this.symbols,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final List<String> symbols;
  final int selected;
  final ValueChanged<int> onSelected;

  /// Only on a real iPhone running iOS 26 or newer.
  static bool get supported => Host.isIOS && nativeGlass;

  @override
  State<NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<NativeTabBar> {
  MethodChannel? _channel;
  bool? _dark;

  void _created(int id) {
    _channel = MethodChannel('sidekick/tabbar/$id')
      ..setMethodCallHandler((call) async {
        if (call.method == 'selected' && call.arguments is int) widget.onSelected(call.arguments as int);
        return null;
      });
  }

  @override
  void didUpdateWidget(NativeTabBar old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) unawaited(_channel?.invokeMethod<void>('select', widget.selected));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_dark != null && _dark != dark) unawaited(_channel?.invokeMethod<void>('dark', dark));
    _dark = dark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: 64 + bottom,
      child: UiKitView(
        viewType: 'sidekick/tabbar',
        onPlatformViewCreated: _created,
        creationParams: {
          'items': [
            for (var i = 0; i < widget.labels.length; i++) {'title': widget.labels[i], 'symbol': widget.symbols[i]},
          ],
          'selected': widget.selected,
          'dark': dark,
        },
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
