import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart' show MethodChannel, StandardMessageCodec;
import 'package:material_ui/material_ui.dart';

import 'widgets.dart' show appleOsMajor;

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
/// as a platform view; the Mac's is the window itself, [windowGlass]). Elsewhere (and in the
/// screenshot tool) [GlassPanel] draws a frosted look of its own.
bool get nativeGlass => Platform.isIOS && (appleOsMajor ?? 0) >= 26;

/// macOS 26: the whole window stands on Apple's glass (NSGlassEffectView
/// behind Sidekick, `setGlass` on `sidekick/macos`), so the desktop shows
/// through, blurred; the backdrop then stays almost clear.
bool get windowGlass => Platform.isMacOS && (appleOsMajor ?? 0) >= 26;

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
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(color: glassRim(scheme)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // Lighter at the top-left, as if lit from above.
              colors: [
                Color.lerp(
                  glassTint(scheme, opacity),
                  Colors.white,
                  scheme.brightness == Brightness.dark ? 0.04 : 0.18,
                )!,
                glassTint(scheme, opacity),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
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
    // The Mac's window is Apple's glass already: only a light tint on top.
    if (windowGlass) {
      return ColoredBox(
        color: scheme.surface.withValues(alpha: dark ? 0.25 : 0.2),
        child: child,
      );
    }
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

/// Turns a Material theme into its Liquid Glass version: see-through
/// backgrounds (the [GlassBackdrop] shows through), translucent cards with a
/// bright rim, and frosted dialogs, sheets and menus.
ThemeData glassTheme(ThemeData base) {
  final scheme = base.colorScheme;
  final rim = BorderSide(color: glassRim(scheme));
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
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
    ),
    appBarTheme: base.appBarTheme.copyWith(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent),
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
  static bool get supported => Platform.isIOS && nativeGlass;

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
