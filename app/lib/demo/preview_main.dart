// The website's preview (getsidekick.app/preview.html): Sidekick compiled
// for a browser. The page shows it twice, as a Mac (?device=mac) and as an
// iPhone (?device=iphone), and passes messages between the two (see
// DemoAppState in demo_state.dart). Build with tool/build_preview.sh.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../core/host.dart';
import '../core/models.dart';
import '../main.dart';
import '../ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final params = Uri.base.queryParameters;
  final device = params['device'] == 'iphone' ? DevicePlatform.ios : DevicePlatform.macos;
  Host.web = device;
  debugHostPlatform = device;
  debugForceMobile = device == DevicePlatform.ios;
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Sidekick preview: $error\n$stack');
    return true;
  };
  await _loadFonts();
  final state = await DemoAppState.create(device, _PageLink(device));
  debugPickFiles = state.pickSamples;
  await state.start();
  final app = SidekickApp(state: state, splash: params['splash'] == '1');
  // An iPhone's screen has the Dynamic Island and the home bar (the page
  // draws them): the app keeps clear of them like on the phone itself.
  const insets = EdgeInsets.only(top: 62, bottom: 34);
  runApp(
    device == DevicePlatform.ios
        ? Builder(
            builder: (context) => MediaQuery.fromView(
              view: View.of(context),
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(padding: insets, viewPadding: insets),
                  child: app,
                ),
              ),
            ),
          )
        : app,
  );
  _window.parent.postMessage(jsonEncode({'from': device.name, 't': 'ready'}).toJS, '*'.toJS);
}

/// Apple's system font can't be shipped, so Inter (very close to it) stands
/// in for every family the app asks for on a Mac or an iPhone.
Future<void> _loadFonts() async {
  const weights = {'Regular': 400, 'Medium': 500, 'SemiBold': 600, 'Bold': 700};
  final files = {
    for (final w in weights.keys) ...{'Inter-$w': 'fonts/Inter-$w.ttf', 'InterDisplay-$w': 'fonts/InterDisplay-$w.ttf'},
  };
  final bytes = <String, Future<ByteData>>{
    for (final MapEntry(:key, :value) in files.entries) key: _fetch(value).then(ByteData.sublistView),
  };
  for (final family in ['.AppleSystemUIFont', 'CupertinoSystemDisplay', 'CupertinoSystemText', 'Roboto']) {
    final loader = FontLoader(family);
    for (final w in weights.keys) {
      loader.addFont(bytes[family == 'CupertinoSystemDisplay' ? 'InterDisplay-$w' : 'Inter-$w']!);
    }
    try {
      await loader.load();
    } catch (e) {
      debugPrint('Sidekick preview: font $family: $e');
    }
  }
}

Future<Uint8List> _fetch(String url) async {
  final response = await _fetchJs(url.toJS).toDart;
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

@JS('fetch')
external JSPromise<_Response> _fetchJs(JSString url);

extension type _Response(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

@JS('window')
external _Window get _window;

extension type _Window(JSObject _) implements JSObject {
  external _Window get parent;
  external void postMessage(JSAny? message, JSString targetOrigin);
  external void addEventListener(JSString type, JSFunction listener);
}

extension type _MessageEvent(JSObject _) implements JSObject {
  external JSAny? get data;
}

/// The page between the two copies: messages go up to it with this
/// device's name, and it hands them to the other copy.
class _PageLink implements DemoLink {
  _PageLink(this.device) {
    _window.addEventListener(
      'message'.toJS,
      ((_MessageEvent e) {
        final data = e.data;
        if (!data.isA<JSString>()) return;
        try {
          final message = (jsonDecode((data as JSString).toDart) as Map).cast<String, Object?>();
          if (message['to'] == device.name) _messages.add(message);
        } catch (_) {
          // Not one of ours.
        }
      }).toJS,
    );
  }

  final DevicePlatform device;
  final _messages = StreamController<Map<String, Object?>>.broadcast();

  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  @override
  void send(Map<String, Object?> message) =>
      _window.parent.postMessage(jsonEncode({...message, 'from': device.name}).toJS, '*'.toJS);
}
