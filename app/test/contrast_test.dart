import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sidekick/app_state.dart';
import 'package:sidekick/ui/nothing.dart';

/// WCAG contrast between two opaque colors (1 to 21).
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Text is readable in every built-in theme: at least 4.5:1 (WCAG AA) for
/// body and secondary text on the backgrounds it sits on, and for the
/// labels on filled buttons.
void main() {
  final schemes = <String, ColorScheme>{
    for (final MapEntry(key: name, value: (_, seed)) in themeColors.entries)
      for (final b in Brightness.values) '$name ${b.name}': ColorScheme.fromSeed(seedColor: seed, brightness: b),
    for (final b in Brightness.values) 'nothing ${b.name}': nothingScheme(b),
  };

  for (final MapEntry(key: name, value: s) in schemes.entries) {
    test(name, () {
      final pairs = {
        'text on the page': (s.onSurface, s.surface),
        'secondary text on the page': (s.onSurfaceVariant, s.surface),
        'secondary text on a card': (s.onSurfaceVariant, s.surfaceContainer),
        'secondary text on a raised card': (s.onSurfaceVariant, s.surfaceContainerHigh),
        'filled button': (s.onPrimary, s.primary),
        'tonal button': (s.onPrimaryContainer, s.primaryContainer),
        'notice': (s.onInverseSurface, s.inverseSurface),
        'error button': (s.onError, s.error),
      };
      for (final MapEntry(key: what, value: (fg, bg)) in pairs.entries) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$name: $what');
      }
    });
  }
}
