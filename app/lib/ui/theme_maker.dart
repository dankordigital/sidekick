import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../core/custom_theme.dart';
import 'app_theme.dart';
import 'glass.dart';
import 'nothing.dart';
import 'nothing_screens.dart' show NothingTabBar;
import 'transfer_screens.dart' show closeRoute;
import 'widgets.dart';

/// Settings → Theme → Make theme: start from a look (Default, Liquid Glass
/// where it's offered, or Nothing), change its colors, and see the app
/// change as you go (like Discord's theme maker). One made theme is kept;
/// saving puts it on.

/// Sidekick's purple, the Default look's accent.
const _purple = Color(0xFF6750A4);

/// The colors a template starts with, light or dark.
CustomTheme starterTheme(ThemeTemplate template, {required bool dark, String name = 'My theme'}) {
  final brightness = dark ? Brightness.dark : Brightness.light;
  final nothing = template == ThemeTemplate.nothing;
  final accent = nothing ? nothingRed : _purple;
  final scheme = nothing ? nothingScheme(brightness) : ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
  return CustomTheme(
    template: template,
    accent: accent.toARGB32(),
    background: scheme.surface.toARGB32(),
    cards: scheme.surfaceContainer.toARGB32(),
    text: scheme.onSurface.toARGB32(),
    name: name,
  );
}

/// The made theme's colors, on its template's palette.
ColorScheme customScheme(CustomTheme theme) {
  final brightness = theme.dark ? Brightness.dark : Brightness.light;
  final accent = Color(theme.accent);
  final background = Color(theme.background);
  final cards = Color(theme.cards);
  final text = Color(theme.text);
  Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  Color on(Color c) => c.computeLuminance() > 0.45 ? Colors.black : Colors.white;
  final nothing = theme.template == ThemeTemplate.nothing;
  final base = nothing
      ? nothingScheme(brightness, accent: accent)
      : ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
  return base.copyWith(
    // Buttons and selections take the accent exactly; in the Nothing look
    // they're ink and the accent is its one red (tertiary).
    primary: nothing ? text : accent,
    onPrimary: nothing ? background : on(accent),
    surface: background,
    surfaceContainerLowest: background,
    surfaceContainerLow: mix(background, cards, 0.6),
    surfaceContainer: cards,
    surfaceContainerHigh: mix(cards, text, 0.05),
    surfaceContainerHighest: mix(cards, text, 0.1),
    onSurface: text,
    onSurfaceVariant: mix(text, background, 0.4),
    outline: mix(background, text, 0.3),
    outlineVariant: mix(background, text, 0.12),
    inverseSurface: text,
    onInverseSurface: background,
  );
}

/// The whole Material theme for a made theme. Liquid Glass falls back to
/// the Default look where it isn't offered.
ThemeData customThemeData(CustomTheme theme) {
  final material = sidekickTheme(customScheme(theme));
  return switch (theme.template) {
    ThemeTemplate.nothing => nothingTheme(material),
    ThemeTemplate.glass when liquidGlassAvailable => glassTheme(material),
    _ => material,
  };
}

/// Whether a made theme draws the glass backdrop under the app.
bool customThemeIsGlass(CustomTheme theme) => theme.template == ThemeTemplate.glass && liquidGlassAvailable;

/// Opens the theme maker, starting from [start] (or from the current look).
Future<void> showThemeMaker(BuildContext context, AppState state, {CustomTheme? start}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final template = state.nothingLook
      ? ThemeTemplate.nothing
      : state.liquidGlass && liquidGlassAvailable
      ? ThemeTemplate.glass
      : ThemeTemplate.material;
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ThemeMakerPage(
        state: state,
        start: start ?? starterTheme(template, dark: dark),
      ),
    ),
  );
}

class ThemeMakerPage extends StatefulWidget {
  const ThemeMakerPage({super.key, required this.state, required this.start});
  final AppState state;
  final CustomTheme start;

  @override
  State<ThemeMakerPage> createState() => _ThemeMakerPageState();
}

/// Which color is being changed.
enum _Part { accent, background, cards, text }

class _ThemeMakerPageState extends State<ThemeMakerPage> {
  late CustomTheme _draft = widget.start;
  late final _name = TextEditingController(text: widget.start.name);
  _Part? _open = _Part.accent;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(CustomTheme theme) => setState(() => _draft = theme);

  int _color(_Part part) => switch (part) {
    _Part.accent => _draft.accent,
    _Part.background => _draft.background,
    _Part.cards => _draft.cards,
    _Part.text => _draft.text,
  };

  void _setColor(_Part part, Color color) {
    final v = color.toARGB32();
    _set(switch (part) {
      _Part.accent => _draft.copyWith(accent: v),
      _Part.background => _draft.copyWith(background: v),
      _Part.cards => _draft.copyWith(cards: v),
      _Part.text => _draft.copyWith(text: v),
    });
  }

  /// A new template starts from its own colors, keeping the light or dark.
  void _template(ThemeTemplate template) => _set(starterTheme(template, dark: _draft.dark, name: _draft.name));

  /// Light or dark: the template's background, cards and text; the accent stays.
  void _brightness(bool dark) =>
      _set(starterTheme(_draft.template, dark: dark, name: _draft.name).copyWith(accent: _draft.accent));

  void _save() {
    final name = _name.text.trim();
    widget.state.setCustomTheme(_draft.copyWith(name: name.isEmpty ? 'My theme' : name));
    closeRoute(context);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    final preview = _LivePreview(theme: _draft);
    final editor = _editor(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => closeRoute(context),
        ),
        title: const Text('Make theme'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 400, child: editor),
                  Expanded(
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Padding(padding: const EdgeInsets.all(28), child: preview),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    height: 340,
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: preview,
                  ),
                  Expanded(child: editor),
                ],
              ),
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contrast = _contrast(Color(_draft.text), Color(_draft.background));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          onChanged: (v) => _draft = _draft.copyWith(name: v),
        ),
        const SizedBox(height: 20),
        Text('Start from', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<ThemeTemplate>(
          showSelectedIcon: false,
          segments: [
            const ButtonSegment(value: ThemeTemplate.material, label: Text('Default')),
            if (liquidGlassAvailable) const ButtonSegment(value: ThemeTemplate.glass, label: Text('Liquid Glass')),
            const ButtonSegment(value: ThemeTemplate.nothing, label: Text('Nothing')),
          ],
          selected: {
            _draft.template == ThemeTemplate.glass && !liquidGlassAvailable ? ThemeTemplate.material : _draft.template,
          },
          onSelectionChanged: (s) => _template(s.first),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
            ButtonSegment(value: true, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
          ],
          selected: {_draft.dark},
          onSelectionChanged: (s) => _brightness(s.first),
        ),
        const SizedBox(height: 20),
        Text('Colors', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final part in _Part.values)
          _ColorRow(
            label: switch (part) {
              _Part.accent => _draft.template == ThemeTemplate.nothing ? 'Accent (the red)' : 'Accent',
              _Part.background => 'Background',
              _Part.cards => 'Cards',
              _Part.text => 'Text',
            },
            color: Color(_color(part)),
            presets: switch (part) {
              _Part.accent => _accents,
              _Part.background => _backgrounds,
              _Part.cards => _backgrounds,
              _Part.text => _texts,
            },
            open: _open == part,
            onToggle: () => setState(() => _open = _open == part ? null : part),
            onChanged: (c) => _setColor(part, c),
          ),
        if (contrast < 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The text is hard to read on this background.',
                    style: TextStyle(color: scheme.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _set(starterTheme(_draft.template, dark: _draft.dark, name: _draft.name)),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Start over'),
          ),
        ),
      ],
    );
  }

  /// WCAG contrast ratio between two colors (1 … 21).
  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}

const _accents = [
  Color(0xFFD71921),
  Color(0xFFF97316),
  Color(0xFFF59E0B),
  Color(0xFF22C55E),
  Color(0xFF14B8A6),
  Color(0xFF0EA5E9),
  Color(0xFF3B82F6),
  Color(0xFF6366F1),
  _purple,
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF0D0D0D),
];

const _backgrounds = [
  Color(0xFFFFFFFF),
  Color(0xFFF2F2EF),
  Color(0xFFF5EFE6),
  Color(0xFFE8EEF8),
  Color(0xFFEDE7F6),
  Color(0xFFE6F2EA),
  Color(0xFF000000),
  Color(0xFF0A0A0A),
  Color(0xFF161615),
  Color(0xFF111827),
  Color(0xFF1A1225),
  Color(0xFF0F1A14),
];

const _texts = [
  Color(0xFF0D0D0D),
  Color(0xFF1E293B),
  Color(0xFF3B2F2F),
  Color(0xFFFFFFFF),
  Color(0xFFF0F0EC),
  Color(0xFFE2E8F0),
];

/// One color: its swatch and hex; open, presets and hue / saturation /
/// brightness sliders.
class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.color,
    required this.presets,
    required this.open,
    required this.onToggle,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final List<Color> presets;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<Color> onChanged;

  String get _hex => '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hsv = HSVColor.fromColor(color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: _Swatch(color: color, size: 34, selected: false),
          title: Text(label),
          subtitle: Text(_hex, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          trailing: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          onTap: onToggle,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: !open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in presets)
                            _Swatch(
                              color: c,
                              size: 32,
                              selected: c.toARGB32() == color.toARGB32(),
                              onTap: () => onChanged(c),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _slider(context, 'Hue', hsv.hue / 360, [
                        for (var h = 0; h <= 360; h += 60) HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
                      ], (v) => onChanged(hsv.withHue(v * 360).toColor())),
                      _slider(context, 'Saturation', hsv.saturation, [
                        hsv.withSaturation(0).toColor(),
                        hsv.withSaturation(1).toColor(),
                      ], (v) => onChanged(hsv.withSaturation(v).toColor())),
                      _slider(context, 'Brightness', hsv.value, [
                        Colors.black,
                        hsv.withValue(1).toColor(),
                      ], (v) => onChanged(hsv.withValue(v).toColor())),
                      Divider(color: scheme.outlineVariant),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// A slider on a strip of the colors it moves through.
  Widget _slider(BuildContext context, String name, double value, List<Color> track, ValueChanged<double> onChanged) =>
      Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(name, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 10,
                trackShape: _GradientTrack(track),
                thumbColor: Colors.white,
                overlayColor: Colors.black12,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2),
              ),
              child: Slider(value: value.clamp(0, 1), onChanged: onChanged),
            ),
          ),
        ],
      );
}

/// A rounded track painted with [colors] from left to right.
class _GradientTrack extends RoundedRectSliderTrackShape {
  const _GradientTrack(this.colors);
  final List<Color> colors;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    context.canvas
      ..drawRRect(shape, Paint()..shader = LinearGradient(colors: colors).createShader(rect))
      ..drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.black12,
      );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.size, required this.selected, this.onTap});
  final Color color;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? scheme.onSurface : scheme.outlineVariant, width: selected ? 3 : 1),
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                size: size * 0.55,
                color: color.computeLuminance() > 0.45 ? Colors.black : Colors.white,
              )
            : null,
      ),
    );
  }
}

// ------------------------------------------------------------------ the preview

/// A small, made-up Devices screen in [theme], like a phone, scaled to fit.
/// It changes the moment a color does.
class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.theme});
  final CustomTheme theme;

  @override
  Widget build(BuildContext context) {
    final data = customThemeData(theme);
    final nothing = theme.template == ThemeTemplate.nothing;
    Widget screen = nothing ? const _NothingMock() : const _MaterialMock();
    if (customThemeIsGlass(theme)) screen = GlassBackdrop(child: screen);
    return Semantics(
      label: 'Preview of the theme',
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Center(
            child: FittedBox(
              child: Container(
                width: 360,
                height: 720,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(color: Theme.of(context).colorScheme.outline, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: data,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: 24, bottom: 12)),
                    child: Material(
                      color: customThemeIsGlass(theme) ? Colors.transparent : data.colorScheme.surface,
                      child: screen,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialMock extends StatelessWidget {
  const _MaterialMock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 40, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Devices', style: text.headlineMedium?.copyWith(color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text('2 devices ready · encrypted', style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 18),
                Card(
                  child: ListTile(
                    leading: const IconTile(Icons.phone_android_rounded, tone: TileTone.primary),
                    title: const Text('Pixel 9'),
                    subtitle: const Text('Connected'),
                    trailing: FilledButton(onPressed: () {}, child: const Text('Send')),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const IconTile(Icons.laptop_mac_rounded),
                    title: const Text('MacBook Air'),
                    subtitle: const Text('On Wi-Fi'),
                    trailing: OutlinedButton(onPressed: () {}, child: const Text('Ping')),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sending Trip.mov', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(value: 0.62),
                        const SizedBox(height: 8),
                        Text('25 MB of 41 MB', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Always accept from Pixel 9'),
                  value: true,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
        NavigationBar(
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.devices_outlined),
              selectedIcon: Icon(Icons.devices),
              label: 'Devices',
            ),
            NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Files'),
            NavigationDestination(icon: Icon(Icons.mouse_outlined), label: 'Remote'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ],
        ),
      ],
    );
  }
}

class _NothingMock extends StatelessWidget {
  const _NothingMock();

  Widget _row(BuildContext context, IconData icon, String name, String how, bool on) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            NothingRing(icon, on: on),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      NothingDot(on: on),
                      const SizedBox(width: 7),
                      NothingLabel(how, size: 9.5),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
      const NothingHair(),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 40, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const DotLogo(height: 14),
                  const Spacer(),
                  NothingChip(label: '+ Connect', onPressed: () {}),
                ],
              ),
              const SizedBox(height: 26),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DotText('2', dot: 12),
                  SizedBox(width: 14),
                  Text('devices\nready', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500, height: 1.05)),
                ],
              ),
              const SizedBox(height: 26),
              const NothingSection('Your devices'),
              const NothingHair(),
              _row(context, Icons.phone_android_outlined, 'Pixel 9', 'Connected', true),
              _row(context, Icons.laptop_mac_outlined, 'MacBook Air', 'Offline', false),
              const SizedBox(height: 18),
              const LinearProgressIndicator(value: 0.62),
              const SizedBox(height: 8),
              const NothingLabel('Sending Trip.mov · 62%', size: 9.5),
              const Spacer(),
              NothingButton(label: 'Send files', icon: Icons.north_east_rounded, onPressed: () {}),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
      NothingTabBar(index: 0, onTap: (_) {}),
    ],
  );
}
