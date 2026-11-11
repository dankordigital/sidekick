// Every tab at every size, at 100 % and 150 % text, in the default look and
// the Nothing look: anything that doesn't fit (Flutter's "overflowed by N
// pixels") fails the run, and is listed in build/screenshots/sizes/.
//
//   flutter test tool/sizes_test.dart
//   flutter test tool/sizes_test.dart --dart-define=SIDEKICK_LOOK=nothing
//
// Sizes: phones (360×740, 430×932), a tablet both ways (820×1180,
// 1180×820), a small laptop (1280×800) and a big screen (1920×1080). A
// picture of each lands in build/screenshots/sizes/ (half size).

// This is a test in all but location.
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
import 'package:sidekick/core/crypto.dart';
import 'package:sidekick/core/models.dart';
import 'package:sidekick/core/server.dart';
import 'package:sidekick/core/trust.dart';
import 'package:sidekick/main.dart';
import 'package:sidekick/platform/files.dart';
import 'package:sidekick/platform/input.dart';
import 'package:sidekick/ui/widgets.dart';

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
  const look = String.fromEnvironment('SIDEKICK_LOOK', defaultValue: 'default');

  testWidgets('every screen fits at every size ($look look)', (tester) async {
    HttpOverrides.global = null;
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({'name': 'Gaming PC', 'welcomed': true});
    final out = Directory('build/screenshots/sizes')..createSync(recursive: true);

    late AppState state;
    late SidekickServer phone;
    late Directory home;
    final phoneId = newDeviceId();
    await tester.runAsync(() async {
      await _loadFonts();
      home = Directory(p.join((await Directory.systemTemp.createTemp('sidekick_sizes')).path, 'Internal storage'))
        ..createSync();
      for (final dir in ['Camera', 'Download', 'Music', 'Documents']) {
        Directory(p.join(home.path, dir)).createSync();
      }
      File(p.join(home.path, 'Holiday_2026_with_a_rather_long_name.mp4')).writeAsBytesSync(List.filled(2123456, 0));
      phone = SidekickServer(
        identity: Identity.generate(),
        self: () => DeviceInfo(
          id: phoneId,
          name: 'Pixel 9 Pro Fold',
          platform: DevicePlatform.android,
          port: phone.port,
          capabilities: const Capabilities(files: true, input: true),
        ),
        trust: TrustStore(),
        files: FileService(home: home.path),
        input: UnsupportedInputInjector(),
        inputReady: () async => true,
        receiveDir: () async => home.path,
      );
      await phone.start(port: 0, address: InternetAddress.loopbackIPv4);
      state = await AppState.load();
      await state.start();
      final target = DeviceInfo(
        id: phoneId,
        name: 'Pixel 9 Pro Fold',
        platform: DevicePlatform.android,
        port: phone.port,
        address: '127.0.0.1',
      );
      final pin = phone.events.where((e) => e is PairRequested).cast<PairRequested>().first;
      await state.requestPairing(target);
      await state.confirmPairing(target, (await pin).request.pin);
    });
    state.setNothingLook(look == 'nothing');

    final overflows = <String>{};
    var where = '';
    final report = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        overflows.add('$where: ${text.split('\n').first}');
      } else {
        report?.call(details);
      }
    };

    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: SidekickApp(state: state),
      ),
    );
    Future<void> wait([int ms = 150]) async {
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final tabs = look == 'nothing'
        ? ['DEVICES', 'SEND', 'REMOTE', 'SETTINGS']
        : ['Devices', 'Files', 'Remote', 'Settings'];
    for (final (w, h, kind) in [
      (360.0, 740.0, 'phone'),
      (430.0, 932.0, 'phone'),
      (820.0, 1180.0, 'tablet'),
      (1180.0, 820.0, 'tablet'),
      (1280.0, 800.0, 'computer'),
      (1920.0, 1080.0, 'computer'),
    ]) {
      debugForceMobile = kind != 'computer';
      tester.view.physicalSize = Size(w, h);
      for (final scale in [1.0, 1.5]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await wait();
        for (final tab in tabs) {
          final name =
              '${look == 'nothing' ? 'nothing-' : ''}${w.round()}x${h.round()}-${(scale * 100).round()}-${tab.toLowerCase()}';
          where = name;
          // The Nothing side bar (computers) says "Devices", its tab bar "DEVICES".
          final target = find.byWidgetPredicate((w) => w is Text && w.data?.toLowerCase() == tab.toLowerCase());
          if (target.evaluate().isEmpty) {
            overflows.add('$name: no "$tab" tab to tap');
            continue;
          }
          await tester.tap(target.last, warnIfMissed: false);
          // Files and Remote load from the other device.
          await wait(tab.toLowerCase() == 'files' || tab.toLowerCase() == 'remote' ? 600 : 150);
          await tester.runAsync(() async {
            final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 0.5);
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            File(p.join(out.path, '$name.png')).writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      }
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    FlutterError.onError = report;
    debugForceMobile = false;
    File(p.join(out.path, 'overflows-$look.txt')).writeAsStringSync(overflows.join('\n'));

    await tester.runAsync(() async {
      await phone.stop();
      await state.server.stop();
      await state.discovery.stop();
      await home.parent.delete(recursive: true);
    });
    await tester.pumpWidget(const SizedBox());
    // Files and Remote look for the phone when they open (15 s at most, by
    // the clock): let those searches end.
    for (var i = 0; i < 40 && state.isFinding(phoneId); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pump(const Duration(seconds: 2));
    expect(overflows, isEmpty, reason: 'every screen fits at every size');
  });
}
