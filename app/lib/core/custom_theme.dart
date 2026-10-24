import 'dart:convert';
import 'dart:math' as math;

/// The look a custom theme starts from (Settings → Theme → Make theme).
enum ThemeTemplate {
  /// Sidekick's usual Material look.
  material,

  /// Apple's Liquid Glass (offered on iOS and macOS 26+ only).
  glass,

  /// The Nothing look: dots, hairlines, one accent color.
  nothing,
}

/// A theme someone made: a template and four colors. The background decides
/// whether it's light or dark, so it looks the same in light and dark mode.
class CustomTheme {
  const CustomTheme({
    required this.template,
    required this.accent,
    required this.background,
    required this.cards,
    required this.text,
    this.name = 'My theme',
  });

  final ThemeTemplate template;

  /// Colors as 0xAARRGGBB.
  final int accent;
  final int background;
  final int cards;
  final int text;
  final String name;

  /// Whether the background is dark (then the theme is a dark one).
  bool get dark => luminance(background) < 0.4;

  CustomTheme copyWith({ThemeTemplate? template, int? accent, int? background, int? cards, int? text, String? name}) =>
      CustomTheme(
        template: template ?? this.template,
        accent: accent ?? this.accent,
        background: background ?? this.background,
        cards: cards ?? this.cards,
        text: text ?? this.text,
        name: name ?? this.name,
      );

  Map<String, Object> toJson() => {
    'template': template.name,
    'accent': accent,
    'background': background,
    'cards': cards,
    'text': text,
    'name': name,
  };

  String encode() => jsonEncode(toJson());

  /// Null when [source] isn't a saved theme (missing, or from a broken write).
  static CustomTheme? decode(String? source) {
    if (source == null) return null;
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      int color(String key) => (json[key] as num).toInt() & 0xFFFFFFFF;
      return CustomTheme(
        template: ThemeTemplate.values.asNameMap()[json['template']] ?? ThemeTemplate.material,
        accent: color('accent'),
        background: color('background'),
        cards: color('cards'),
        text: color('text'),
        name: (json['name'] as String?)?.trim().isNotEmpty == true ? (json['name'] as String).trim() : 'My theme',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CustomTheme &&
      other.template == template &&
      other.accent == accent &&
      other.background == background &&
      other.cards == cards &&
      other.text == text &&
      other.name == name;

  @override
  int get hashCode => Object.hash(template, accent, background, cards, text, name);
}

/// Relative luminance (0 black … 1 white) of a 0xAARRGGBB color.
double luminance(int argb) {
  double channel(int shift) {
    final c = ((argb >> shift) & 0xFF) / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}
