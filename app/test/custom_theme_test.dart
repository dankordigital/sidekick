import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidekick/app_state.dart';
import 'package:sidekick/core/custom_theme.dart';
import 'package:sidekick/ui/nothing.dart';
import 'package:sidekick/ui/theme_maker.dart';

void main() {
  const blueOnBlack = CustomTheme(
    template: ThemeTemplate.nothing,
    accent: 0xFF3B82F6,
    background: 0xFF000000,
    cards: 0xFF161615,
    text: 0xFFF0F0EC,
    name: 'Night',
  );

  test('a made theme survives saving and reading back', () {
    expect(CustomTheme.decode(blueOnBlack.encode()), blueOnBlack);
    expect(CustomTheme.decode(null), isNull);
    expect(CustomTheme.decode('not json'), isNull, reason: 'a broken pref falls back to no theme');
    expect(
      CustomTheme.decode('{"template":"x","accent":1,"background":2,"cards":3,"text":4,"name":" "}')?.name,
      'My theme',
    );
  });

  test('the background decides light or dark', () {
    expect(blueOnBlack.dark, isTrue);
    expect(blueOnBlack.copyWith(background: 0xFFF2F2EF).dark, isFalse);
    expect(starterTheme(ThemeTemplate.material, dark: true).dark, isTrue);
    expect(starterTheme(ThemeTemplate.nothing, dark: false).dark, isFalse);
  });

  test('the theme uses the colors that were picked', () {
    final theme = customThemeData(blueOnBlack);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.surface, const Color(0xFF000000));
    expect(theme.colorScheme.surfaceContainer, const Color(0xFF161615));
    expect(theme.colorScheme.onSurface, const Color(0xFFF0F0EC));
    // Nothing: the accent replaces the red, and the screens know it's Nothing.
    expect(theme.colorScheme.tertiary, const Color(0xFF3B82F6));
    expect(theme.extension<NothingLook>()?.on, isTrue);

    final material = customThemeData(blueOnBlack.copyWith(template: ThemeTemplate.material));
    expect(material.colorScheme.primary, const Color(0xFF3B82F6), reason: 'buttons take the accent exactly');
    expect(material.extension<NothingLook>()?.on ?? false, isFalse);
  });

  testWidgets('Make theme: pick a look, see it, name it, save it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = (await tester.runAsync(AppState.load))!;
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(onPressed: () => showThemeMaker(context, state), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Make theme'), findsOneWidget);

    // Start from Nothing: the preview turns into the Nothing look at once.
    await tester.tap(find.text('Nothing'));
    await tester.pumpAndSettle();
    expect(find.text('Send files'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Night');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(state.customLook, isTrue);
    expect(state.customTheme?.name, 'Night');
    expect(state.customTheme?.template, ThemeTemplate.nothing);
    expect(state.nothingIcon, isTrue, reason: 'a theme made from Nothing gets the Nothing app icon');

    // Picking another look keeps the made theme to come back to.
    state.setNothingLook(false);
    expect(state.customLook, isFalse);
    expect(state.customTheme, isNotNull);
    state.useCustomTheme();
    expect(state.customLook, isTrue);
    state.deleteCustomTheme();
    expect(state.customTheme, isNull);
    expect(state.customLook, isFalse);
  });
}
