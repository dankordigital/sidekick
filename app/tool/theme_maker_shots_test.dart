// Renders Settings → Theme → Make theme (phone and computer, a few drafts)
// into build/screenshots/theme-maker-*.png:
//
//   flutter test tool/theme_maker_shots_test.dart

// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidekick/app_state.dart';
import 'package:sidekick/core/custom_theme.dart';
import 'package:sidekick/ui/app_theme.dart';
import 'package:sidekick/ui/theme_maker.dart';

Future<void> _loadFonts() async {
  final fonts = p.join(
    Platform.environment['FLUTTER_ROOT'] ?? '/home/user/tools/flutter',
    'bin/cache/artifacts/material_fonts',
  );
  Future<ByteData> read(String name) async => ByteData.sublistView(await File(p.join(fonts, name)).readAsBytes());
  await (FontLoader('Roboto')
        ..addFont(read('Roboto-Regular.ttf'))
        ..addFont(read('Roboto-Medium.ttf'))
        ..addFont(read('Roboto-Bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
  const mono = '/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf';
  if (File(mono).existsSync()) {
    await (FontLoader('monospace')..addFont(Future.value(ByteData.sublistView(File(mono).readAsBytesSync())))).load();
  }
}

void main() {
  testWidgets('theme maker', (tester) async {
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({'name': 'Gaming PC'});
    final out = Directory('build/screenshots')..createSync(recursive: true);
    late AppState state;
    await tester.runAsync(() async {
      await _loadFonts();
      state = await AppState.load();
    });
    final boundary = GlobalKey();
    final app = sidekickTheme(ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)));

    Future<void> shot(String name, Size size, CustomTheme start) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: app,
            home: ThemeMakerPage(key: UniqueKey(), state: state, start: start),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(p.join(out.path, '$name.png')).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    const phone = Size(412, 915), computer = Size(1280, 840);
    await shot('theme-maker-phone', phone, starterTheme(ThemeTemplate.material, dark: false));
    await shot(
      'theme-maker-phone-nothing',
      phone,
      starterTheme(ThemeTemplate.nothing, dark: true).copyWith(accent: 0xFF3B82F6, name: 'Blue Nothing'),
    );
    await shot(
      'theme-maker-computer',
      computer,
      starterTheme(
        ThemeTemplate.material,
        dark: true,
      ).copyWith(accent: 0xFF14B8A6, background: 0xFF0F1A14, cards: 0xFF17261D, name: 'Forest'),
    );
    await shot('theme-maker-computer-nothing', computer, starterTheme(ThemeTemplate.nothing, dark: false));
  });
}
