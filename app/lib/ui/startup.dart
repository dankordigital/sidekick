import 'package:material_ui/material_ui.dart';

import 'widgets.dart';

/// The intro, played once: the first time Sidekick opens, before setup.
///
/// The "sk" tile pops in and the name rises under it, then it fades into the
/// app. The app isn't built until it's done, so nothing under it can be
/// touched. A tap skips it; with reduced motion it doesn't play at all.
class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key, required this.child});

  final Widget child;

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  bool _done = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _done = true;
      return;
    }
    _c.forward().whenComplete(_finish);
  }

  void _finish() {
    if (mounted && !_done) setState(() => _done = true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Animation<double> part(double from, double to, [Curve curve = Curves.easeOutCubic]) => CurvedAnimation(
      parent: _c,
      curve: Interval(from, to, curve: curve),
    );
    final pop = part(0.0, 0.4, Curves.easeOutBack);
    final title = part(0.2, 0.5);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _done
          ? widget.child
          : GestureDetector(
              key: const ValueKey('splash'),
              behavior: HitTestBehavior.opaque,
              onTap: _finish,
              child: ColoredBox(
                color: scheme.surface,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(scale: pop.value, child: const LogoTile(size: 96)),
                        const SizedBox(height: 24),
                        Opacity(
                          opacity: title.value,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - title.value)),
                            child: Column(
                              children: [
                                Text('Sidekick', style: text.headlineMedium?.copyWith(color: scheme.onSurface)),
                                const SizedBox(height: 4),
                                Text(
                                  'Your devices, together',
                                  style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
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

/// What shows while Sidekick starts: the logo and a bar that keeps moving.
/// It runs before the settings are read, so it follows the system's light
/// or dark and the chosen color only.
class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key, required this.seed, this.themeMode = ThemeMode.system});

  final Color seed;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b),
      useMaterial3: true,
      // ignore: deprecated_member_use
      progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
    );
    return MaterialApp(
      title: 'Sidekick',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const Scaffold(body: Loading(child: LogoTile(size: 72))),
    );
  }
}
