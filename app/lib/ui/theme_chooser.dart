import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'theme_maker.dart';
import 'widgets.dart';

/// Light/dark mode, color theme and pure black: used in Settings → Theme and
/// on the welcome screen.
class ThemeChooser extends StatelessWidget {
  const ThemeChooser({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // The look: Default (Material), Nothing (every platform), on iOS and
      // macOS 26+ Apple's Liquid Glass, the theme made in Make theme, and
      // Make theme itself.
      ListTile(
        leading: const IconTile(Icons.auto_awesome_outlined),
        title: const Text('Theme'),
        trailing: DropdownButton<String>(
          value: state.customLook
              ? 'custom'
              : state.nothingLook
              ? 'nothing'
              : state.liquidGlass && liquidGlassAvailable
              ? 'glass'
              : 'default',
          underline: const SizedBox(),
          borderRadius: BorderRadius.circular(16),
          items: [
            const DropdownMenuItem(value: 'default', child: Text('Default')),
            const DropdownMenuItem(value: 'nothing', child: Text('Nothing')),
            if (liquidGlassAvailable) const DropdownMenuItem(value: 'glass', child: Text('Liquid Glass')),
            if (state.customTheme case final made?)
              DropdownMenuItem(
                value: 'custom',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(made.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            const DropdownMenuItem(
              value: 'make',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.palette_outlined, size: 18), SizedBox(width: 8), Text('Make theme…')],
              ),
            ),
          ],
          onChanged: (v) => switch (v) {
            'make' => showThemeMaker(context, state),
            'custom' => state.useCustomTheme(),
            'nothing' => state.setNothingLook(true),
            'glass' => state.setLiquidGlass(true),
            _ => state.setNothingLook(false),
          },
        ),
      ),
      // The made theme: change it, or throw it away.
      if (state.customLook && state.customTheme != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Made themes keep their own colors, light or dark.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ),
              TextButton(onPressed: () => _delete(context), child: const Text('Delete')),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: () => showThemeMaker(context, state, start: state.customTheme),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit theme'),
              ),
            ],
          ),
        ),
      if (!state.customLook)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
            ],
            selected: {state.themeMode},
            onSelectionChanged: (s) => state.setThemeMode(s.first),
          ),
        ),
      // The Nothing look has its own colors: black, white, grey and red; a
      // made theme has the ones it was made with.
      if (!state.nothingLook && !state.customLook) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Color', style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (!hostIsIOS)
                _ColorChoice(
                  label: switch (hostOS) {
                    'android' => 'Wallpaper',
                    _ => 'System accent',
                  },
                  selected: state.themeColor == 'system',
                  onTap: () => state.setThemeColor('system'),
                ),
              for (final MapEntry(:key, value: (label, color)) in themeColors.entries)
                _ColorChoice(
                  label: label,
                  color: color,
                  mono: key == 'mono',
                  // iOS has no system colors; its default is purple.
                  selected: state.themeColor == key || (hostIsIOS && state.themeColor == 'system' && key == 'purple'),
                  onTap: () => state.setThemeColor(key),
                ),
            ],
          ),
        ),
        if (state.themeColor == 'system' && !hostIsIOS)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(switch (hostOS) {
              'android' => 'Follows your wallpaper colors (Android 12 and newer).',
              'macos' => "Follows your Mac's accent color (System Settings → Appearance).",
              _ => 'Follows your Windows accent color (Settings → Personalization → Colors).',
            }, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
        SwitchListTile(
          secondary: const IconTile(Icons.contrast_rounded),
          title: const Text('Pure black in dark mode'),
          subtitle: const Text('Darker backgrounds; saves battery on OLED screens'),
          value: state.pureBlack,
          onChanged: state.setPureBlack,
        ),
      ],
    ],
  );
}

extension on ThemeChooser {
  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${state.customTheme?.name}"?'),
        content: const Text('Sidekick goes back to the Default theme. You can make a new one any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) state.deleteCustomTheme();
  }
}

/// A round color swatch with its name, for Settings → Theme.
class _ColorChoice extends StatelessWidget {
  const _ColorChoice({required this.label, required this.selected, required this.onTap, this.color, this.mono = false});

  final String label;

  /// Null for "follow the system".
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final swatch = color == null
        ? null
        : ColorScheme.fromSeed(
            seedColor: color!,
            brightness: Theme.of(context).brightness,
            dynamicSchemeVariant: mono ? DynamicSchemeVariant.monochrome : DynamicSchemeVariant.tonalSpot,
          );
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: swatch == null
                        ? SweepGradient(colors: [scheme.primary, scheme.tertiary, scheme.secondary, scheme.primary])
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [swatch.primary, swatch.primary, swatch.primaryContainer, swatch.primaryContainer],
                            stops: const [0, 0.62, 0.62, 1],
                          ),
                    border: Border.all(color: selected ? scheme.onSurface : Colors.transparent, width: 3),
                  ),
                  child: selected ? Icon(Icons.check, color: swatch?.onPrimary ?? scheme.onPrimary) : null,
                ),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
