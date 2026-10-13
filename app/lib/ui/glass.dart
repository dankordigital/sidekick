import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart' show StandardMessageCodec;
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
/// NSGlassEffectView on macOS 26), as platform views. Elsewhere (and in the
/// screenshot tool) [GlassPanel] draws a frosted look of its own.
bool get nativeGlass => (Platform.isIOS || Platform.isMacOS) && (appleOsMajor ?? 0) >= 26;

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
      final glass = Platform.isIOS
          ? UiKitView(
              viewType: 'sidekick/glass',
              creationParams: params,
              creationParamsCodec: const StandardMessageCodec(),
            )
          : AppKitView(
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
        decoration: BoxDecoration(gradient: blob(const Alignment(-0.9, -0.8), scheme.primaryContainer, 1.1)),
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
