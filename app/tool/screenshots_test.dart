// Renders every tab to PNG so the UI can be checked without a Windows
// machine. Not part of the normal test run:
//
//   flutter test tool/screenshots_test.dart
//   (every size and text scale: tool/sizes_test.dart)
//
// Screenshots land in build/screenshots/.

// This is a test in all but location.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sidekick/app_state.dart';
import 'package:sidekick/core/client.dart';
import 'package:sidekick/core/crypto.dart';
import 'package:sidekick/core/history.dart';
import 'package:sidekick/core/models.dart';
import 'package:sidekick/core/server.dart';
import 'package:sidekick/core/trust.dart';
import 'package:sidekick/main.dart';
import 'package:sidekick/platform/files.dart';
import 'package:sidekick/platform/desktop_window.dart';
import 'package:sidekick/platform/input.dart';
import 'package:sidekick/ui/dock.dart';
import 'package:sidekick/ui/files_page.dart';
import 'package:sidekick/ui/send_page.dart';
import 'package:sidekick/ui/startup.dart';
import 'package:sidekick/ui/tray_panel.dart';
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
  // Sidekick 4.0's typeface, bundled with the app.
  await (FontLoader('Inter')
        ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Inter-Regular.otf').readAsBytesSync())))
        ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Inter-Medium.otf').readAsBytesSync())))
        ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Inter-SemiBold.otf').readAsBytesSync())))
        ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/Inter-Bold.otf').readAsBytesSync()))))
      .load();
  // The Nothing look's labels use the system's monospaced font ("monospace"
  // on Linux); any mono font on this machine stands in for it.
  const mono = '/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf';
  if (File(mono).existsSync()) {
    await (FontLoader('monospace')..addFont(Future.value(ByteData.sublistView(File(mono).readAsBytesSync())))).load();
  }
}

void main() {
  testWidgets('screenshots', (tester) async {
    // Widget tests fake all HTTP by default; this one needs real sockets.
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1280, 840);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({'name': 'Gaming PC'});
    final out = Directory('build/screenshots')..createSync(recursive: true);

    late AppState state;
    late SidekickServer phone;
    late Directory home;
    final phoneId = newDeviceId();

    await tester.runAsync(() async {
      await _loadFonts();
      // A friendly folder name: it shows up in the Files breadcrumb.
      home = Directory(p.join((await Directory.systemTemp.createTemp('sidekick_shots')).path, 'Internal storage'))
        ..createSync();
      for (final dir in ['Camera', 'Download', 'Music', 'Documents']) {
        Directory(p.join(home.path, dir)).createSync();
      }
      File(p.join(home.path, 'Holiday_2026.mp4')).writeAsBytesSync(List.filled(2123456, 0));
      File(p.join(home.path, 'Screenshot_0412.png')).writeAsBytesSync(List.filled(312345, 0));

      phone = SidekickServer(
        identity: Identity.generate(),
        self: () => DeviceInfo(
          id: phoneId,
          name: 'Pixel 9',
          platform: DevicePlatform.android,
          port: phone.port,
          capabilities: const Capabilities(files: true, input: true),
        ),
        trust: TrustStore(),
        files: FileService(home: home.path),
        input: UnsupportedInputInjector(),
        // Pretend remote control is allowed, so Remote shows a live touchpad.
        inputReady: () async => true,
        receiveDir: () async => home.path,
      );
      await phone.start(port: 0, address: InternetAddress.loopbackIPv4);

      state = await AppState.load();
      await state.start();

      final target = DeviceInfo(
        id: phoneId,
        name: 'Pixel 9',
        platform: DevicePlatform.android,
        port: phone.port,
        address: '127.0.0.1',
      );
      final pin = phone.events.where((e) => e is PairRequested).cast<PairRequested>().first;
      await state.requestPairing(target);
      await state.confirmPairing(target, (await pin).request.pin);
      // What the two shared, for the Chat tab.
      final now = DateTime.now();
      for (final item in [
        HistoryItem.file(
          device: phoneId,
          fromMe: false,
          name: 'Travel checklist.pdf',
          size: 2400000,
          path: p.join(home.path, 'Travel checklist.pdf'),
          at: now.subtract(const Duration(hours: 3)),
        ),
        HistoryItem.text(
          device: phoneId,
          fromMe: true,
          text: 'Door code 4417',
          at: now.subtract(const Duration(hours: 2)),
        ),
        HistoryItem.file(
          device: phoneId,
          fromMe: false,
          name: 'Beach day.jpg',
          size: 4800000,
          at: now.subtract(const Duration(minutes: 50)),
        ),
        HistoryItem.text(
          device: phoneId,
          fromMe: false,
          text: 'https://www.bbcgoodfood.com/recipes/lemon-drizzle-cake',
          at: now.subtract(const Duration(minutes: 20)),
        ),
        HistoryItem.text(
          device: phoneId,
          fromMe: false,
          text: 'Your Google verification code is 482913',
          at: now.subtract(const Duration(minutes: 2)),
        ),
      ]) {
        state.history.add(item);
      }
      // As in the design: the phone is a favourite, answers on the same
      // Wi-Fi, and a MacBook waits for an answer ("Needs you").
      state.setAlwaysAccept(phoneId, true);
      state
        ..wifiConnected = true
        ..lan = ['192.168.1.24'];
      await state.addByAddress('127.0.0.1:${phone.port}');
      state.waitingOffers.add(
        TransferOffer(
          id: 'needs-you',
          from: TrustedPeer(
            id: 'mac',
            name: 'MacBook Pro',
            platform: DevicePlatform.macos,
            token: 't',
            fingerprint: 'f',
            key: 'k',
          ),
          files: const [
            OfferedFile('IMG_1842.heic', 8200000),
            OfferedFile('IMG_1843.heic', 7800000),
            OfferedFile('Coast walk.mov', 109600000),
            OfferedFile('Weekend plans.pdf', 2400000),
          ],
        ),
      );
    });

    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: SidekickApp(state: state),
      ),
    );

    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    /// Waits until the page has loaded (no spinner left), up to ~10 s.
    Future<void> loaded() async {
      for (
        var i = 0;
        i < 20 &&
            (find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
                find.byType(Loading).evaluate().isNotEmpty);
        i++
      ) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String name, {bool waitForData = false}) async {
      await settle();
      if (waitForData) await loaded();
      // Let entrance animations (list rows, cards) finish.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(p.join(out.path, '$name.png')).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    // First launch: the welcome flow, once.
    for (var i = 1; find.text('Continue').evaluate().isNotEmpty; i++) {
      await shot('0-welcome-$i');
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await shot('0-welcome-last');
    await tester.tap(find.text('Start using Sidekick'));
    expect(state.welcomed, isTrue);
    await shot('1-devices');
    await tester.tap(find.text('+ Connect'));
    await shot('1b-devices-connect-menu');
    // QR code pairing: this device's code, then the 6-digit code with its QR
    // (an iPhone asking, so it can scan).
    await tester.tap(find.text('QR code'));
    await shot('1c-qr-code');
    await tester.tap(find.text('Close'));
    await settle();
    await tester.runAsync(
      () => PeerClient(host: '127.0.0.1', port: state.server.port).requestPairing(
        DeviceInfo(id: newDeviceId(), name: 'iPhone 17', platform: DevicePlatform.ios, port: 1),
        myFingerprint: Identity.generate().fingerprint,
      ),
    );
    await shot('1d-pin-with-qr');
    await tester.tap(find.text('Cancel'));
    await settle();
    // Send: two files and a link chosen.
    final sample = Directory.systemTemp.createTempSync('sk-send');
    final zip = File(p.join(sample.path, 'Trail photos.zip'))..writeAsBytesSync(List.filled(45300, 0));
    final pdf = File(p.join(sample.path, 'Weekend plans.pdf'))..writeAsBytesSync(List.filled(2400, 0));
    sendSelection.value = [Picked.file(zip), Picked.file(pdf)];
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Send')));
    await shot('2-send');
    // Browse files is a device's own screen now (its hold menu).
    unawaited(showFilesOf(tester.element(find.byType(NavigationRail)), state, state.paired.first));
    await shot('2b-files', waitForData: true);
    if (find.text('Home').evaluate().isNotEmpty) {
      await tester.tap(find.text('Home'));
      await shot('2c-files-folder', waitForData: true);
    }
    await tester.pageBack();
    await settle();
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Remote')));
    await shot('3-remote', waitForData: true);
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Settings')));
    await shot('5-settings');
    state.setThemeMode(ThemeMode.dark);
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Devices')));
    await shot('6-devices-dark');

    // Phone layout. The 4.0 dock shows only the selected tab's name: the
    // others are found by their label, as a screen reader finds them.
    Finder tab(String name) =>
        find.descendant(of: find.byType(FloatingDock), matching: find.bySemanticsLabel(name)).last;
    state.setThemeMode(ThemeMode.light);
    debugForceMobile = true;
    tester.view.physicalSize = const Size(412, 915);
    await settle();
    for (final (tab_, name) in [
      ('Devices', 'devices'),
      ('Chat', 'chat'),
      ('Send', 'send'),
      ('Remote', 'remote'),
      ('Settings', 'settings'),
    ]) {
      await tester.tap(tab(tab_));
      await shot('phone-$name', waitForData: name == 'remote');
    }
    await tester.tap(tab('Devices'));
    await settle();
    await tester.tap(find.text('+ Connect'));
    await settle();
    await tester.tap(find.text('QR code'));
    await shot('phone-qr-code');
    await tester.tap(find.text('Close'));
    await settle();

    // The welcome flow on a phone.
    state.welcomed = false;
    state.setThemeMode(ThemeMode.light); // also rebuilds
    await shot('phone-welcome-1');
    await tester.tap(find.text('Continue'));
    await shot('phone-welcome-2');
    state.finishWelcome();
    await settle();

    // iPhone Settings: iOS never allows remote control, so no such switch.
    debugHostPlatform = DevicePlatform.ios;
    await tester.tap(tab('Settings'));
    await settle();
    final list = find.byType(Scrollable).first;
    await tester.dragUntilVisible(find.text('What paired devices can do here'), list, const Offset(0, -200));
    await shot('iphone-settings-permissions');
    expect(find.text('Control mouse and keyboard'), findsNothing);
    await tester.dragUntilVisible(find.text('Everything is encrypted'), list, const Offset(0, -200));
    await shot('iphone-settings-encryption');
    await tester.ensureVisible(find.textContaining('security code'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('security code'));
    await shot('iphone-security-code');
    await tester.tap(find.text('Done'));

    state.setThemeMode(ThemeMode.light);
    debugForceMobile = true;
    tester.view.physicalSize = const Size(412, 915);

    // The startup animation, a few frames in (desktop, light).
    debugForceMobile = false;
    state.setThemeColor('purple');
    state.setThemeMode(ThemeMode.light);
    state.setPureBlack(false);
    tester.view.physicalSize = const Size(1280, 840);
    await settle(); // let the theme change finish first
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: SidekickApp(state: state, splash: true),
      ),
    );
    // Every 50 ms, for a GIF: startup-00.png, startup-01.png, …
    for (var frame = 0; frame * 50 <= 1800; frame++) {
      await tester.pump(Duration(milliseconds: frame == 0 ? 0 : 50));
      final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 0.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(p.join(out.path, 'startup-${frame.toString().padLeft(2, '0')}.png'))
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }
    await tester.pump(const Duration(seconds: 1));

    // The loading screen, while Sidekick starts.
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: LoadingApp(seed: themeColors['purple']!.$2, themeMode: ThemeMode.light),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await shot('loading');

    // The panel the tray / menu-bar icon opens (Windows, Mac).
    tester.view.physicalSize = DesktopWindow.panelSize * 2;
    tester.view.devicePixelRatio = 2;
    for (final (name, theme) in [
      ('tray-panel', ThemeData(colorSchemeSeed: const Color(0xFF6750A4), fontFamily: 'Roboto')),
    ]) {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            key: ValueKey(name),
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: TrayPanel(state: state),
          ),
        ),
      );
      await settle();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(p.join(out.path, '$name.png')).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await tester.runAsync(() async {
      await phone.stop();
      await state.server.stop();
      await state.discovery.stop();
      await home.parent.delete(recursive: true);
    });
    await tester.pumpWidget(const SizedBox());
  });
}
