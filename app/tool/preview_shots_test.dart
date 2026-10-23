// Renders the website's live preview (preview.html): the real app on a Mac
// (1280×800) and an iPhone (393×852), every tab, and an iPhone sending
// files to the Mac (asking, Accept or Decline, the progress on both).
// Not part of the normal test run:
//
//   flutter test tool/preview_shots_test.dart --dart-define=DEVICE=iphone
//   flutter test tool/preview_shots_test.dart --dart-define=DEVICE=mac
//   python3 tool/make_preview.py
//
// One device per run: together, each would find the other on the network.
//
// Frames land in build/preview/<device>/; where the buttons are goes to
// build/preview/<device>.json, so the page can make them clickable.
// Inter stands in for San Francisco when build/fonts/ has it (see
// make_preview.py); otherwise Roboto.

// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'dart:convert';
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
import 'package:sidekick/ui/transfer_screens.dart';
import 'package:sidekick/ui/widgets.dart';

/// 15 frames a second: smooth enough, and small enough for a web page.
const _frame = Duration(microseconds: 66667);

const _tabs = ['Devices', 'Files', 'Remote', 'Settings'];

const _device = String.fromEnvironment('DEVICE');

Future<void> _loadFonts() async {
  final flutterFonts = p.join(
    Platform.environment['FLUTTER_ROOT'] ?? '/home/user/tools/flutter',
    'bin/cache/artifacts/material_fonts',
  );
  Future<ByteData> read(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  await (FontLoader('MaterialIcons')..addFont(read(p.join(flutterFonts, 'MaterialIcons-Regular.otf')))).load();
  final inter = Directory('build/fonts/x/extras/ttf').existsSync() ? 'build/fonts/x/extras/ttf' : null;
  for (final family in ['.AppleSystemUIFont', 'CupertinoSystemDisplay', 'CupertinoSystemText', 'Roboto']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      final file = inter == null
          ? p.join(flutterFonts, 'Roboto-${weight == 'SemiBold' ? 'Medium' : weight}.ttf')
          : p.join(inter, '${family == 'CupertinoSystemDisplay' ? 'InterDisplay' : 'Inter'}-$weight.ttf');
      loader.addFont(read(file));
    }
    await loader.load();
  }
}

/// An iPhone shares only Sidekick's own folder (see FileService.roots).
class _IphoneFiles extends FileService {
  _IphoneFiles(this.home) : super(home: home);
  final String home;

  @override
  Future<List<RemoteEntry>> roots() async => [RemoteEntry(name: 'Sidekick files', path: home, isDir: true)];
}

/// Saves the screen and remembers where things are on it.
class _Shots {
  _Shots(this.tester, this.device, this.state, this.peer);

  final WidgetTester tester;
  final String device;
  final AppState state;
  final SidekickServer peer;
  final key = GlobalKey();
  final Map<String, Object> manifest = {};
  late final dir = Directory('build/preview/$device')..createSync(recursive: true);

  Future<void> save(String name) async {
    if (!name.contains('/')) await keepOnline();
    // Its own Wi-Fi check runs on a real timer and finds none here.
    state
      ..wifiConnected = true
      ..notifyListeners();
    await tester.pump();
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(p.join(dir.path, '$name.png')).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  /// [count] frames, 15 a second, as name/NNN.png.
  Future<void> frames(String name, int count, {void Function(int i)? each}) async {
    Directory(p.join(dir.path, name)).createSync(recursive: true);
    for (var i = 0; i < count; i++) {
      if (i % 8 == 0) await keepOnline();
      each?.call(i);
      await tester.pump(i == 0 ? Duration.zero : _frame);
      await save('$name/${i.toString().padLeft(3, '0')}');
    }
    manifest['seq:$name'] = count;
  }

  /// The app shows a device as connected for 25 s after it last heard from
  /// it, in real time, and rendering is slow: say hello again.
  /// Also says it's on Wi-Fi: the machine rendering this may not be.
  Future<void> keepOnline() async {
    state
      ..wifiConnected = true
      ..addresses = ['192.168.1.24'];
    await tester.runAsync(() => state.addByAddress('127.0.0.1:${peer.port}').then((_) {}, onError: (_) {}));
  }

  /// Waits (in real time too: pages load over a socket) until [ready] or
  /// ~10 s.
  Future<void> settle({bool Function()? ready}) async {
    for (var i = 0; i < 40; i++) {
      if (i % 8 == 0) await keepOnline();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 300));
      if (i >= 6 && (ready == null || ready())) break;
    }
    // Let what just loaded finish fading in.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Where [finder] is, in logical pixels: [left, top, width, height].
  List<double>? rect(Finder finder) {
    if (finder.evaluate().isEmpty) return null;
    final r = tester.getRect(finder.last);
    return [r.left, r.top, r.width, r.height].map((v) => (v * 10).roundToDouble() / 10).toList();
  }

  /// The four tabs (in the iPhone's tab bar or the Mac's sidebar), each an
  /// area 80 wide around its icon and label.
  void tabs() {
    final bar = find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail);
    manifest['tabs'] = {
      for (final t in _tabs)
        t: () {
          final r = tester.getRect(find.descendant(of: bar, matching: find.text(t)));
          return [r.center.dx - 40, r.top - 42, 80.0, r.height + 50];
        }(),
    };
  }

  /// The button showing [label].
  List<double> button(String label) =>
      rect(find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton))) ??
      rect(find.text(label))!;

  Future<void> tab(String name, {String? waitFor}) async {
    await tester.tap(find.text(name).last);
    await settle(
      ready: () =>
          find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          (waitFor == null || find.text(waitFor).evaluate().isNotEmpty),
    );
  }

  void write() {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    manifest['size'] = [size.width, size.height];
    manifest['dpr'] = tester.view.devicePixelRatio;
    File('build/preview/$device.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(manifest));
  }
}

void main() {
  Future<AppState> start(WidgetTester tester, String name, String receiveDir) async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({
      'name': name,
      'welcomed': true,
      'receiveDir': receiveDir,
      // The one-time "iPhones can't be controlled" pop-up; the Remote tab still says why.
      'iphoneRemoteNotice': true,
    });
    late AppState state;
    await tester.runAsync(() async {
      await _loadFonts();
      state = await AppState.load();
      await state.start();
      await state.discovery.stop();
      state.addresses = ['192.168.1.24'];
    });
    return state;
  }

  /// The other device: a real server on loopback with a few files, paired
  /// with [state], so it shows as connected and its files can be browsed.
  Future<SidekickServer> pairWith(
    WidgetTester tester,
    AppState state,
    String name,
    DevicePlatform platform,
    Map<String, int> files,
  ) async {
    late SidekickServer peer;
    await tester.runAsync(() async {
      final id = newDeviceId();
      // Named like the real thing: the Files breadcrumb shows it.
      final home = Directory(
        p.join(
          (await Directory.systemTemp.createTemp('sidekick_preview')).path,
          platform == DevicePlatform.ios ? 'Documents' : 'sam',
        ),
      )..createSync();
      for (final MapEntry(key: path, value: size) in files.entries) {
        if (size < 0) {
          Directory(p.join(home.path, path)).createSync(recursive: true);
        } else {
          File(p.join(home.path, path))
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(Uint8List(size));
        }
      }
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
        files: platform == DevicePlatform.ios ? _IphoneFiles(home.path) : FileService(home: home.path),
        input: UnsupportedInputInjector(),
        inputReady: () async => true,
        receiveDir: () async => home.path,
      );
      await peer.start(port: 0, address: InternetAddress.loopbackIPv4);
      final target = DeviceInfo(id: id, name: name, platform: platform, port: peer.port, address: '127.0.0.1');
      final pin = peer.events.where((e) => e is PairRequested).cast<PairRequested>().first;
      await state.requestPairing(target);
      await state.confirmPairing(target, (await pin).request.pin);
    });
    return peer;
  }

  Future<void> finish(WidgetTester tester, AppState state, SidekickServer peer) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 4));
    await tester.runAsync(state.server.stop);
    await tester.runAsync(peer.stop);
    debugForceMobile = false;
    debugHostPlatform = null;
    debugCurrentPlatform = null;
    debugDefaultTargetPlatformOverride = null;
  }

  const sendFiles = ['IMG_2041.HEIC', 'IMG_2042.HEIC', 'Trip.mov'];
  const sendSizes = [3200000, 2900000, 41000000];

  testWidgets('iphone', skip: _device != 'iphone', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.padding = const FakeViewPadding(top: 62 * 2, bottom: 34 * 2);
    tester.view.viewPadding = const FakeViewPadding(top: 62 * 2, bottom: 34 * 2);
    debugForceMobile = true;
    debugHostPlatform = DevicePlatform.ios;
    debugCurrentPlatform = DevicePlatform.ios;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final state = await start(
      tester,
      'iPhone 17 Pro',
      '/var/mobile/Containers/Data/Application/5C1F2E8A-3D4B-4E7A-9C61-0B8D2F47A913/Documents',
    );
    final mac = await pairWith(tester, state, 'MacBook Pro', DevicePlatform.macos, {
      'Desktop/Notes.txt': 4200,
      'Desktop/Invoice_0923.pdf': 182000,
      'Documents/Budget 2026.numbers': 512000,
      'Documents/School': -1,
      'Downloads/SidekickSetup.dmg': 48000000,
      'Movies': -1,
      'Music': -1,
      'Pictures/Holiday': -1,
    });
    final shots = _Shots(tester, 'iphone', state, mac);
    await tester.pumpWidget(
      RepaintBoundary(
        key: shots.key,
        child: SidekickApp(state: state),
      ),
    );
    await shots.settle();
    shots.tabs();
    await shots.save('devices');
    shots.manifest['send'] = shots.button('Send');

    await shots.tab('Files', waitFor: 'Desktop');
    await shots.save('files');
    await shots.tab('Remote');
    await shots.settle(ready: () => find.text('Not connected').evaluate().isEmpty);
    await shots.save('remote');
    shots.manifest['touchpad'] =
        shots.rect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Touchpad')) ?? <double>[];
    await shots.tab('Settings');
    await shots.save('settings');
    await shots.tab('Devices');
    await shots.settle();

    // Sending to the Mac: asking, then (on Accept) the progress and Sent.
    OutgoingSend newSend() =>
        OutgoingSend(device: state.paired.first, names: sendFiles, total: sendSizes.reduce((a, b) => a + b))
          ..phase = SendPhase.waiting;
    final context = tester.element(find.byType(Scaffold).first);
    var send = newSend();
    showSendingScreen(context, send).ignore();
    await shots.frames('send-wait', 30);
    send.phase = SendPhase.sending;
    await shots.frames(
      'send-progress',
      30,
      each: (i) => send
        ..done = (send.total * Curves.easeInOut.transform(i / 29)).round()
        ..current = (i * 3 ~/ 30).clamp(0, 2)
        ..notifyListeners(),
    );
    send
      ..phase = SendPhase.done
      ..notifyListeners();
    await shots.frames('send-done', 30);
    await tester.pump(const Duration(seconds: 5));
    await shots.settle();

    // And when the Mac declines.
    send = newSend();
    showSendingScreen(context, send).ignore();
    await tester.pump(const Duration(seconds: 1));
    send
      ..phase = SendPhase.declined
      ..notifyListeners();
    await shots.frames('send-declined', 30);

    shots.write();
    await finish(tester, state, mac);
  });

  testWidgets('mac', skip: _device != 'mac', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1280 * 2, 800 * 2);
    debugHostPlatform = DevicePlatform.macos;
    debugCurrentPlatform = DevicePlatform.macos;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final state = await start(tester, 'MacBook Pro', '/Users/sam/Downloads/Sidekick');
    final phone = await pairWith(tester, state, 'iPhone 17 Pro', DevicePlatform.ios, {
      'Received/Boarding pass.pdf': 240000,
      'Received/Slides.key': 8400000,
      'Photos': -1,
      'IMG_1988.HEIC': 2800000,
      'Voice memo.m4a': 1200000,
    });
    final shots = _Shots(tester, 'mac', state, phone);
    await tester.pumpWidget(
      RepaintBoundary(
        key: shots.key,
        child: SidekickApp(state: state),
      ),
    );
    await shots.settle();
    shots.tabs();
    await shots.save('devices');
    await shots.tab('Files', waitFor: 'Sidekick files');
    await tester.tap(find.text('Sidekick files').last);
    await shots.settle(ready: () => find.text('Received').evaluate().isNotEmpty);
    await shots.save('files');
    await shots.tab('Remote');
    await shots.save('remote');
    await shots.tab('Settings');
    await shots.save('settings');
    await shots.tab('Devices');
    await shots.settle();

    // The iPhone asks to send; the card arrives, then Accept.
    TransferOffer newOffer(String id) => TransferOffer(
      id: id,
      from: TrustedPeer(
        id: state.paired.first.id,
        name: 'iPhone 17 Pro',
        platform: DevicePlatform.ios,
        token: 't',
        fingerprint: 'f',
        key: 'k',
      ),
      files: [for (var i = 0; i < sendFiles.length; i++) OfferedFile(sendFiles[i], sendSizes[i])],
    );
    final context = tester.element(find.byType(Scaffold).first);
    var offer = newOffer('a');
    showIncomingOffer(context, offer).ignore();
    await shots.frames('offer', 30);
    shots.manifest['accept'] = shots.button('Accept');
    shots.manifest['decline'] = shots.button('Decline');
    await tester.tap(find.text('Accept'));
    var sent = 0;
    var file = 0;
    await shots.frames(
      'receive-progress',
      30,
      each: (i) {
        final target = (offer.totalBytes * Curves.easeInOut.transform(i / 29)).round();
        var end = 0;
        for (var k = 0; k <= file && k < offer.files.length; k++) {
          end += offer.files[k].size;
        }
        while (file < offer.files.length && target >= end) {
          offer.debugReceived(offer.files[file].size, fileDone: true);
          sent = end;
          file++;
          if (file < offer.files.length) end += offer.files[file].size;
        }
        if (target > sent) {
          offer.debugReceived(target - sent);
          sent = target;
        }
      },
    );
    await shots.frames('receive-done', 30);
    await tester.pump(const Duration(seconds: 5));
    await shots.settle();

    // And Decline.
    offer = newOffer('b');
    showIncomingOffer(context, offer).ignore();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Decline'));
    await shots.frames('declined', 12);

    shots.write();
    await finish(tester, state, phone);
  });
}
