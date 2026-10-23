import 'dart:async';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'core/host.dart';
import 'core/models.dart';
import 'platform/autoload.dart';
import 'platform/desktop_window.dart';
import 'platform/sound.dart';
import 'ui/corner_popup.dart';
import 'ui/glass.dart';
import 'ui/widgets.dart';
import 'ui/shell.dart';
import 'ui/startup.dart';
import 'ui/tray_panel.dart';
import 'ui/welcome.dart';

Future<void> main([List<String> args = const []]) async {
  AutoLoad.args = args;
  WidgetsFlutterBinding.ensureInitialized();
  _catchErrors();
  try {
    // Windows and Mac: closing the window keeps Sidekick in the tray.
    if (DesktopWindow.supported) {
      try {
        await DesktopWindow.instance.init(startHidden: AutoLoad.launchedHidden);
      } catch (e) {
        debugPrint('Sidekick: no tray: $e');
      }
    }
    // Started at login (Auto-load): quietly, in the tray.
    final quiet = AutoLoad.launchedHidden;
    if (!quiet) await _showLoading();
    final state = await AppState.load();
    await state.start();
    // The intro plays once, before setup; after that the app just opens.
    runApp(SidekickApp(state: state, splash: !quiet && !state.welcomed));
    // Its own call, not part of the animation: with "Reduce motion" on
    // there's no animation, but the chime still plays.
    if (state.sound && !quiet) unawaited(playStartupSound());
  } catch (error) {
    // Never a blank window: say what went wrong and offer to try again.
    runApp(_StartupFailed(error: error, retry: main));
  }
}

/// The loading screen, until the app is ready. Only the theme's color and
/// light/dark are read for it; everything else loads behind it.
Future<void> _showLoading() async {
  var seed = themeColors['purple']!.$2;
  var mode = ThemeMode.system;
  try {
    final prefs = await SharedPreferences.getInstance();
    seed = themeColors[prefs.getString('themeColor')]?.$2 ?? seed;
    mode = ThemeMode.values.asNameMap()[prefs.getString('themeMode')] ?? mode;
  } catch (_) {}
  runApp(LoadingApp(seed: seed, themeMode: mode));
}

/// Errors nothing else caught are logged instead of taking the app down,
/// and a widget that fails to build shows a quiet note, not a red screen.
void _catchErrors() {
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Sidekick: unexpected error: $error\n$stack');
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Something went wrong showing this part. Switch tabs and back to retry.',
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: TextStyle(color: Color(0xFF888888), fontSize: 13),
        ),
      ),
    );
  }
}

class _StartupFailed extends StatelessWidget {
  const _StartupFailed({required this.error, required this.retry});
  final Object error;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sidekick',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF6750A4), useMaterial3: true),
    darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF6750A4), brightness: Brightness.dark, useMaterial3: true),
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 16),
                const Text("Sidekick couldn't start", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SidekickApp extends StatelessWidget {
  const SidekickApp({super.key, required this.state, this.splash = false});

  final AppState state;

  /// Play the intro first (the first time Sidekick opens).
  final bool splash;

  /// Material You, Sidekick style: the colors come from the wallpaper or the
  /// chosen theme; shapes are soft and generous, headlines bold.
  static ThemeData _theme(ColorScheme scheme) {
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
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      listTileTheme: ListTileThemeData(shape: round16, iconColor: scheme.onSurfaceVariant),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, padding: buttonPadding, textStyle: buttonText),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: buttonSize, padding: buttonPadding, textStyle: buttonText),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(0, 40), textStyle: buttonText),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
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

  /// Themes are built once per look: the app rebuilds on every change (up to
  /// ten times a second during a transfer), and building a palette from a
  /// seed color and a full theme each time made every rebuild re-theme the
  /// whole app.
  static final _themes = <Object, ThemeData>{};

  ThemeData _themeFor(ColorScheme? dynamic, Brightness brightness) {
    final key = (state.themeColor, state.pureBlack, brightness, dynamic, _glass);
    final theme = _themes[key];
    if (theme != null) return theme;
    if (_themes.length > 8) _themes.clear();
    final material = _theme(_scheme(dynamic, brightness));
    return _themes[key] = _glass ? glassTheme(material) : material;
  }

  /// Settings → Theme → Liquid Glass, where it's offered (iOS/macOS 26+).
  bool get _glass => state.liquidGlass && liquidGlassAvailable;

  ColorScheme _scheme(ColorScheme? dynamic, Brightness brightness) {
    final choice = state.themeColor;
    ColorScheme scheme;
    if (choice == 'system' && dynamic != null) {
      scheme = dynamic;
    } else {
      // No OS colors (iOS, older Android): Sidekick purple, like the website.
      final (_, seed) = themeColors[choice] ?? themeColors['purple']!;
      scheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        dynamicSchemeVariant: choice == 'mono' ? DynamicSchemeVariant.monochrome : DynamicSchemeVariant.tonalSpot,
      );
    }
    // Pure black would leave nothing for glass to show.
    if (brightness == Brightness.dark && state.pureBlack && !_glass) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0B0B0B),
        surfaceContainer: const Color(0xFF121212),
        surfaceContainerHigh: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFF232323),
      );
    }
    return scheme;
  }

  @override
  Widget build(BuildContext context) {
    // On Windows, DynamicColorBuilder builds the palette from the user's
    // accent color (Settings → Personalization → Colors).
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Sidekick',
          debugShowCheckedModeBanner: false,
          themeMode: state.themeMode,
          theme: _themeFor(lightDynamic, Brightness.light),
          darkTheme: _themeFor(darkDynamic, Brightness.dark),
          builder: (context, child) {
            // Liquid Glass: the colored backdrop sits under every screen.
            if (_glass) child = GlassBackdrop(child: child ?? const SizedBox());
            return DesktopWindow.supported ? _withCornerPopup(context, child) : child ?? const SizedBox();
          },
          home: _maybeSplash(
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: state.welcomed ? Shell(state: state) : WelcomeFlow(state: state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _maybeSplash(Widget app) => splash ? StartupSplash(child: app) : app;

  /// In the tray, a request shows only the small corner card; the rest of
  /// the app stays as it was, not drawn and not animating.
  Widget _withCornerPopup(BuildContext context, Widget? child) => ListenableBuilder(
    listenable: Listenable.merge([
      DesktopWindow.instance.popup,
      DesktopWindow.instance.hidden,
      DesktopWindow.instance.panel,
    ]),
    builder: (context, _) {
      final offer = DesktopWindow.instance.popup.value;
      final panel = DesktopWindow.instance.panel.value && offer == null;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: offer != null || panel,
            // In the tray nothing's on screen: no animations ticking away.
            child: TickerMode(
              enabled: offer == null && !panel && !DesktopWindow.instance.hidden.value,
              child: child ?? const SizedBox(),
            ),
          ),
          if (offer != null) CornerPopup(offer: offer, onDone: DesktopWindow.instance.popupDone, sounds: state.sound),
          // Its own navigator: tooltips and its dialogs need one.
          if (panel)
            Navigator(
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => TrayPanel(state: state),
                transitionDuration: Duration.zero,
              ),
            ),
        ],
      );
    },
  );
}
