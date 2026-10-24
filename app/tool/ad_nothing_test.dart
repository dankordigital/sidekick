// Renders the Nothing look's screens for the Nothing-style ad: an iPhone 17
// Pro (402×874 at 3x) and a MacBook Pro (1280×800 at 2x), paired with real
// loopback stand-ins so every device shows as connected. Not part of the
// normal test run:
//
//   SIDEKICK_MONO=… flutter test tool/ad_nothing_test.dart
//
// Stills land in build/ad-nothing/<name>.png, animations (30 fps) in
// build/ad-nothing/<scene>/NNN.png. SIDEKICK_MONO is a folder with
// JetBrainsMono-400/500/700.ttf, standing in for Menlo; Inter (installed
// here) stands in for San Francisco. SIDEKICK_LIGHT=1 renders paper instead
// of ink.

// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
import 'package:sidekick/ui/nothing_screens.dart';
import 'package:sidekick/ui/ping.dart';
import 'package:sidekick/ui/transfer_screens.dart';
import 'package:sidekick/ui/widgets.dart';

const _frame = Duration(microseconds: 33333);
final _light = Platform.environment['SIDEKICK_LIGHT'] == '1';
final _out = _light ? 'build/ad-nothing/light' : 'build/ad-nothing';

Future<void> _loadFonts() async {
  final flutterFonts = p.join(
    Platform.environment['FLUTTER_ROOT'] ?? '/home/user/tools/flutter',
    'bin/cache/artifacts/material_fonts',
  );
  Future<ByteData> read(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  await (FontLoader('MaterialIcons')..addFont(read(p.join(flutterFonts, 'MaterialIcons-Regular.otf')))).load();
  const inter = '/usr/share/fonts/opentype/inter';
  for (final family in ['.AppleSystemUIFont', 'CupertinoSystemDisplay', 'CupertinoSystemText', 'Roboto']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        read(p.join(inter, '${family == 'CupertinoSystemDisplay' ? 'InterDisplay' : 'Inter'}-$weight.otf')),
      );
    }
    await loader.load();
  }
  final mono = Platform.environment['SIDEKICK_MONO'];
  if (mono != null) {
    for (final family in ['Menlo', 'monospace', 'Roboto Mono', 'Consolas']) {
      final loader = FontLoader(family);
      for (final weight in [400, 500, 700]) {
        loader.addFont(read(p.join(mono, 'JetBrainsMono-$weight.ttf')));
      }
      await loader.load();
    }
  }
}

/// A folder that looks like someone's Mac home.
Directory _macHome() {
  final home = Directory(p.join(Directory.systemTemp.createTempSync('sidekick_ad').path, 'Anna'))..createSync();
  for (final dir in ['Desktop', 'Documents', 'Downloads', 'Movies', 'Music', 'Pictures']) {
    Directory(p.join(home.path, dir)).createSync();
  }
  for (final (name, size) in [
    ('Pitch deck.key', 18400000),
    ('Invoice_October.pdf', 214000),
    ('Holiday_2026.mov', 412000000),
    ('Playlist.m4a', 8100000),
  ]) {
    final f = File(p.join(home.path, name))..createSync();
    // Sparse: the size shows without writing it all.
    final raf = f.openSync(mode: FileMode.write)..setPositionSync(size - 1);
    raf
      ..writeByteSync(0)
      ..closeSync();
  }
  return home;
}

void main() {
  final peers = <SidekickServer>[];

  Future<AppState> start(WidgetTester tester, String name) async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({'name': name, 'welcomed': true, 'iphoneRemoteNoticeSeen': true});
    late AppState state;
    await tester.runAsync(() async {
      await _loadFonts();
      state = await AppState.load();
      await state.start();
      await state.discovery.stop();
      state.addresses = ['192.168.1.24'];
    });
    state.setNothingLook(true);
    state.setThemeMode(_light ? ThemeMode.light : ThemeMode.dark);
    return state;
  }

  /// A real server on loopback that [state] pairs with, so it shows as
  /// paired and connected (and, for a computer, with remote control allowed).
  Future<PairedDevice> pairWith(
    WidgetTester tester,
    AppState state,
    String name,
    DevicePlatform platform, {
    Directory? home,
  }) async {
    late SidekickServer peer;
    final id = newDeviceId();
    await tester.runAsync(() async {
      final dir = home ?? await Directory.systemTemp.createTemp('sidekick_peer');
      peer = SidekickServer(
        identity: Identity.generate(),
        self: () => DeviceInfo(
          id: id,
          name: name,
          platform: platform,
          port: peer.port,
          capabilities: const Capabilities(files: true, input: true),
        ),
        trust: TrustStore(),
        files: FileService(home: dir.path),
        input: UnsupportedInputInjector(),
        inputReady: () async => true,
        receiveDir: () async => dir.path,
      );
      await peer.start(port: 0, address: InternetAddress.loopbackIPv4);
      final target = DeviceInfo(id: id, name: name, platform: platform, port: peer.port, address: '127.0.0.1');
      final pin = peer.events.where((e) => e is PairRequested).cast<PairRequested>().first;
      await state.requestPairing(target);
      await state.confirmPairing(target, (await pin).request.pin);
      // In reach (seen devices expire), so the rows are green.
      await state.addByAddress('127.0.0.1:${peer.port}');
    });
    peers.add(peer);
    return state.paired.firstWhere((d) => d.id == id);
  }

  void iphone(WidgetTester tester) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.padding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    tester.view.viewPadding = const FakeViewPadding(top: 62 * 3, bottom: 34 * 3);
    debugForceMobile = true;
    debugHostPlatform = DevicePlatform.ios;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  }

  void mac(WidgetTester tester) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1280 * 2, 800 * 2);
    debugHostPlatform = DevicePlatform.macos;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  }

  Future<void> save(WidgetTester tester, GlobalKey key, String path) async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  /// Waits (in real time too: pages load over sockets), then saves a still.
  Future<void> still(WidgetTester tester, GlobalKey key, String name, {bool Function()? ready}) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 300));
      final busy = find.byType(Loading).evaluate().isNotEmpty;
      if (i >= 6 && !busy && (ready == null || ready())) break;
    }
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await save(tester, key, p.join(_out, '$name.png'));
  }

  /// Saves [count] frames as build/ad-nothing/[scene]/NNN.png, from [first].
  Future<int> frames(WidgetTester tester, GlobalKey key, String scene, int count, {int first = 0}) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(i == 0 && first == 0 ? Duration.zero : _frame);
      await save(tester, key, p.join(_out, scene, '${(first + i).toString().padLeft(3, '0')}.png'));
    }
    return first + count;
  }

  Future<void> finish(WidgetTester tester, AppState state) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    // Past the direct link's 3-minute idle timer.
    await tester.pump(const Duration(minutes: 4));
    await tester.runAsync(() async {
      await state.server.stop();
      for (final peer in peers) {
        await peer.stop();
      }
    });
    peers.clear();
    sendSelection.value = const [];
    debugForceMobile = false;
    debugHostPlatform = null;
    debugDefaultTargetPlatformOverride = null;
  }

  Future<GlobalKey> app(WidgetTester tester, AppState state) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: SidekickApp(state: state),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return key;
  }

  /// Switches the phone's tab (the bar's own callback: taps on it miss in
  /// the test's iPhone layout).
  Future<void> tab(WidgetTester tester, String name) async {
    tester.widget<NothingTabBar>(find.byType(NothingTabBar)).onTap(nothingTabs.indexOf(name));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Files picked on the Send tab: three photos and a video (the iPhone),
  /// or the documents the Mac sends back.
  Future<void> pick(WidgetTester tester, {bool documents = false}) async {
    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('sidekick_picked')) as Directory;
    sendSelection.value = [
      for (final (name, size)
          in documents
              ? [('Pitch deck.key', 18400000), ('Invoice_October.pdf', 214000)]
              : [
                  ('IMG_2041.HEIC', 3200000),
                  ('IMG_2042.HEIC', 2900000),
                  ('IMG_2043.HEIC', 3400000),
                  ('Trip.mov', 41000000),
                ])
        File(p.join(dir.path, name))..writeAsBytesSync(Uint8List(size)),
    ];
  }

  TransferOffer offerFrom(String name, DevicePlatform platform, List<OfferedFile> files) => TransferOffer(
    id: 'ad',
    from: TrustedPeer(id: 'from', name: name, platform: platform, token: 't', fingerprint: 'f', key: 'k'),
    files: files,
  );

  /// Plays [offer] arriving: [ask] frames of the card, Accept, then the files
  /// coming in over [over] frames, then [after] frames.
  Future<void> receive(
    WidgetTester tester,
    GlobalKey key,
    String scene,
    TransferOffer offer, {
    int ask = 45,
    int over = 45,
    int after = 30,
  }) async {
    var n = await frames(tester, key, scene, ask);
    final accept = find.text('ACCEPT').evaluate().isNotEmpty ? find.text('ACCEPT') : find.text('Accept');
    await tester.tap(accept.last);
    n = await frames(tester, key, scene, 2, first: n);
    var sent = 0;
    var file = 0;
    for (var i = 0; i <= over; i++) {
      final target = i >= over - 1
          ? offer.totalBytes
          : (offer.totalBytes * Curves.easeInOut.transform(i / over)).round();
      var end = 0;
      for (var k = 0; k <= file && k < offer.files.length; k++) {
        end += offer.files[k].size;
      }
      while (file < offer.files.length && target >= end) {
        offer.debugReceived(offer.files[file].size - (sent - (end - offer.files[file].size)), fileDone: true);
        sent = end;
        file++;
        if (file < offer.files.length) end += offer.files[file].size;
      }
      if (target > sent) {
        offer.debugReceived(target - sent);
        sent = target;
      }
      n = await frames(tester, key, scene, 1, first: n);
    }
    await frames(tester, key, scene, after, first: n);
  }

  testWidgets('iphone stills', (tester) async {
    iphone(tester);
    final state = await start(tester, 'iPhone 17 Pro');
    final macBook = await pairWith(tester, state, 'MacBook Pro', DevicePlatform.macos, home: _macHome());
    await pairWith(tester, state, 'Gaming PC', DevicePlatform.windows);
    await pairWith(tester, state, 'Pixel 9', DevicePlatform.android);
    final key = await app(tester, state);
    await still(tester, key, 'iphone-devices');
    await tester.tap(find.text('MacBook Pro').first);
    await still(tester, key, 'iphone-device');
    Navigator.of(tester.element(find.byType(NothingDevicePage))).pop();
    await tester.pump(const Duration(seconds: 1));
    await pick(tester);
    await tab(tester, 'Send');
    await still(tester, key, 'iphone-send');
    await tester.tap(find.text('Browse files'));
    await still(tester, key, 'iphone-browse');
    await tester.tap(find.text('Home').first);
    await still(tester, key, 'iphone-browse-home');
    await tester.tap(find.byTooltip('Close'));
    await tester.pump(const Duration(milliseconds: 600));
    state.select(macBook.id);
    await tab(tester, 'Remote');
    await still(tester, key, 'iphone-remote', ready: () => find.text('Not connected').evaluate().isEmpty);
    await tab(tester, 'Devices');
    await tester.pump(const Duration(milliseconds: 600));
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(
      showPinged(
        context,
        state,
        TrustedPeer(
          id: macBook.id,
          name: 'MacBook Pro',
          platform: DevicePlatform.macos,
          token: 't',
          fingerprint: 'f',
          key: 'k',
        ),
      ),
    );
    await frames(tester, key, 'iphone-ping', 60);
    await finish(tester, state);
  });

  testWidgets('iphone sending', (tester) async {
    iphone(tester);
    final state = await start(tester, 'iPhone 17 Pro');
    final key = await app(tester, state);
    final send = OutgoingSend(
      device: PairedDevice(
        id: 'mac',
        name: 'MacBook Pro',
        platform: DevicePlatform.macos,
        token: 't',
        fingerprint: 'f',
        key: 'k',
      ),
      names: ['IMG_2041.HEIC', 'IMG_2042.HEIC', 'IMG_2043.HEIC', 'Trip.mov'],
      total: 50500000,
    )..phase = SendPhase.waiting;
    showSendingScreen(tester.element(find.byType(Scaffold).first), send).ignore();
    var n = await frames(tester, key, 'iphone-sending', 30);
    send.phase = SendPhase.sending;
    for (var i = 0; i < 45; i++) {
      send
        ..done = (send.total * Curves.easeInOut.transform(i / 44)).round()
        ..current = (i * 4 ~/ 45).clamp(0, 3)
        ..notifyListeners();
      n = await frames(tester, key, 'iphone-sending', 1, first: n);
    }
    send
      ..phase = SendPhase.done
      ..notifyListeners();
    await frames(tester, key, 'iphone-sending', 30, first: n);
    await finish(tester, state);
  });

  testWidgets('iphone incoming', (tester) async {
    iphone(tester);
    final state = await start(tester, 'iPhone 17 Pro');
    final key = await app(tester, state);
    final offer = offerFrom('MacBook Pro', DevicePlatform.macos, const [
      OfferedFile('Pitch deck.key', 18400000),
      OfferedFile('Invoice_October.pdf', 214000),
    ]);
    showNothingIncoming(tester.element(find.byType(Scaffold).first), state, offer).ignore();
    await receive(tester, key, 'iphone-incoming', offer, ask: 40, over: 36, after: 30);
    await finish(tester, state);
  });

  testWidgets('mac stills', (tester) async {
    mac(tester);
    final state = await start(tester, 'MacBook Pro');
    await pairWith(tester, state, 'iPhone 17 Pro', DevicePlatform.ios);
    await pairWith(tester, state, 'Pixel 9', DevicePlatform.android);
    final key = await app(tester, state);
    await still(tester, key, 'mac-devices');
    await pick(tester, documents: true);
    await tester.tap(find.text('Send').last);
    await still(tester, key, 'mac-send');
    await finish(tester, state);
  });

  testWidgets('mac incoming', (tester) async {
    mac(tester);
    final state = await start(tester, 'MacBook Pro');
    await pairWith(tester, state, 'iPhone 17 Pro', DevicePlatform.ios);
    final key = await app(tester, state);
    await still(tester, key, 'mac-home');
    final offer = offerFrom('iPhone 17 Pro', DevicePlatform.ios, const [
      OfferedFile('IMG_2041.HEIC', 3200000),
      OfferedFile('IMG_2042.HEIC', 2900000),
      OfferedFile('IMG_2043.HEIC', 3400000),
      OfferedFile('Trip.mov', 41000000),
    ]);
    showNothingIncoming(tester.element(find.byType(Scaffold).first), state, offer).ignore();
    await receive(tester, key, 'mac-incoming', offer, ask: 45, over: 45, after: 36);
    await finish(tester, state);
  });
}
