import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

import '../core/host.dart';
import '../core/models.dart';

/// Sidekick 4.0's one look (the owner's Figma "Foundations", as in
/// design/emulator): a #121212 page, #1c1c1c panels, #262626 raised cards,
/// white pill buttons with dark text, colour only where it means something.
/// Dark only.
ColorScheme sidekick4Scheme() => const ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFF0F0F0),
  onPrimary: Color(0xFF141414),
  primaryContainer: Color(0xFF2E2E2E),
  onPrimaryContainer: Color(0xFFF2F2F2),
  secondary: Color(0xFFA1A1A6),
  onSecondary: Color(0xFF141414),
  secondaryContainer: Color(0xFFF0F0F0),
  onSecondaryContainer: Color(0xFF141414),
  tertiary: Color(0xFF5B9DFF),
  onTertiary: Color(0xFF0A1A33),
  tertiaryContainer: Color(0xFF2F2410),
  onTertiaryContainer: Color(0xFFFFC56B),
  error: Color(0xFFFF6B5E),
  onError: Color(0xFF1A0503),
  errorContainer: Color(0xFF3A1512),
  onErrorContainer: Color(0xFFFFD9D4),
  surface: Color(0xFF121212),
  onSurface: Color(0xFFF2F2F2),
  onSurfaceVariant: Color(0xFFA1A1A6),
  surfaceContainerLowest: Color(0xFF0A0A0A),
  surfaceContainerLow: Color(0xFF1C1C1C),
  surfaceContainer: Color(0xFF1C1C1C),
  surfaceContainerHigh: Color(0xFF262626),
  surfaceContainerHighest: Color(0xFF2E2E2E),
  outline: Color(0xFF5A5A5E),
  outlineVariant: Color(0xFF2E2E2E),
  inverseSurface: Color(0xFFF0F0F0),
  onInverseSurface: Color(0xFF141414),
  inversePrimary: Color(0xFF141414),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  surfaceTint: Color(0x00000000),
);

/// 4.0's colours that aren't part of a Material scheme: amber for "needs
/// you", green for "connected".
const sidekickAmber = Color(0xFFFFC56B);
const sidekickAmberBg = Color(0xFF2F2410);
const sidekickOk = Color(0xFF45D07E);

/// Sidekick's shapes and type on top of a [scheme]: pill buttons, 22 px
/// cards, bold headlines, no shadows.
ThemeData sidekickTheme(ColorScheme scheme) {
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    // The website's preview runs in a browser on any computer: it looks
    // like the Mac or iPhone it plays (fonts, scrolling, switches).
    platform: Host.isWeb
        ? switch (Host.web) {
            DevicePlatform.ios => TargetPlatform.iOS,
            DevicePlatform.macos => TargetPlatform.macOS,
            DevicePlatform.android => TargetPlatform.android,
            DevicePlatform.windows => TargetPlatform.windows,
            _ => null,
          }
        : null,
  );
  final text = base.textTheme;
  TextStyle? bold(TextStyle? s, FontWeight w, [double spacing = 0]) =>
      s?.copyWith(fontWeight: w, letterSpacing: spacing);
  final round16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const pill = StadiumBorder();
  const buttonSize = Size(0, 44);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20);
  // Built from the theme's styles so they keep the platform's font.
  final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w600);
  TextStyle? label(FontWeight w, Color c) => text.labelMedium?.copyWith(fontWeight: w, color: c);
  OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: width),
  );
  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: bold(text.displaySmall, FontWeight.w700, -0.5),
      headlineLarge: bold(text.headlineLarge, FontWeight.w700, -0.5),
      headlineMedium: bold(text.headlineMedium, FontWeight.w700, -0.25),
      headlineSmall: bold(text.headlineSmall, FontWeight.w700),
      titleLarge: bold(text.titleLarge, FontWeight.w600),
      titleMedium: bold(text.titleMedium, FontWeight.w600, 0.1),
    ),
    // One card color everywhere (Devices, Settings, lists), the one the
    // theme maker calls "Cards".
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: buttonText,
        shape: pill,
        elevation: 0,
      ),
    ),
    listTileTheme: ListTileThemeData(shape: round16, iconColor: scheme.onSurfaceVariant),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: buttonText,
        shape: pill,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: buttonText,
        shape: pill,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(0, 40), textStyle: buttonText, shape: pill),
    ),
    chipTheme: const ChipThemeData(shape: StadiumBorder(), side: BorderSide.none),
    inputDecorationTheme: InputDecorationTheme(
      border: field(scheme.outline),
      enabledBorder: field(scheme.outlineVariant),
      focusedBorder: field(scheme.primary, 2),
      errorBorder: field(scheme.error),
      focusedErrorBorder: field(scheme.error, 2),
    ),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? const Icon(Icons.check) : null,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: round16,
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(8)),
      textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      selectedLabelTextStyle: label(FontWeight.w700, scheme.onSurface),
      unselectedLabelTextStyle: label(FontWeight.w500, scheme.onSurfaceVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? label(FontWeight.w700, scheme.onSurface)
            : label(FontWeight.w500, scheme.onSurfaceVariant),
      ),
    ),
    // The current Material 3 progress bars and sliders (rounded, with
    // gaps). The flag is "deprecated" only because it'll become the default.
    // ignore: deprecated_member_use
    progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
    // ignore: deprecated_member_use
    sliderTheme: const SliderThemeData(year2023: false),
    // Apple's push (slide in from the right, the page below easing back)
    // everywhere, so every platform moves the same way.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
