import 'dart:async';
import 'dart:ui';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'platform/autoload.dart';
import 'platform/desktop_window.dart';
import 'platform/sound.dart';
import 'ui/app_theme.dart';
import 'ui/corner_popup.dart';
import 'ui/glass.dart';
import 'ui/nothing.dart';
import 'ui/widgets.dart';
import 'ui/shell.dart';
import 'ui/startup.dart';
import 'ui/theme_maker.dart';
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
  var nothing = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    seed = themeColors[prefs.getString('themeColor')]?.$2 ?? seed;
    mode = ThemeMode.values.asNameMap()[prefs.getString('themeMode')] ?? mode;
    nothing = prefs.getString('look') == 'nothing';
  } catch (_) {}
  runApp(LoadingApp(seed: seed, themeMode: mode, nothing: nothing));
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

  /// Themes are built once per look: the app rebuilds on every change (up to
  /// ten times a second during a transfer), and building a palette from a
  /// seed color and a full theme each time made every rebuild re-theme the
  /// whole app.
  static final _themes = <Object, ThemeData>{};

  ThemeData _themeFor(ColorScheme? dynamic, Brightness brightness) {
    // Settings → Theme → Make theme: the made theme, the same in light and
    // dark (its background decides).
    final custom = state.customLook ? state.customTheme : null;
    final key = custom ?? (state.themeColor, state.pureBlack, brightness, dynamic, _glass, state.nothingLook);
    final theme = _themes[key];
    if (theme != null) return theme;
    if (_themes.length > 8) _themes.clear();
    if (custom != null) return _themes[key] = customThemeData(custom);
    // Settings → Theme → Nothing: its own colors, whatever the color choice.
    if (state.nothingLook) return _themes[key] = nothingTheme(sidekickTheme(nothingScheme(brightness)));
    final material = sidekickTheme(_scheme(dynamic, brightness));
    return _themes[key] = _glass ? glassTheme(material) : material;
  }

  /// Settings → Theme → Liquid Glass, where it's offered (iOS/macOS 26+).
  bool get _glass => state.customLook && state.customTheme != null
      ? customThemeIsGlass(state.customTheme!)
      : state.liquidGlass && liquidGlassAvailable;

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
