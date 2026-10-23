// The browser preview's sounds: the app's own WAVs (bundled as assets)
// in an HTML audio element. Windows' PlaySound isn't there.
import 'dart:js_interop';

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio(String src);
  external set loop(bool value);
  external JSPromise<JSAny?> play();
  external void pause();
}

_Audio? _looping;

Future<void> webPlaySound(String name, {bool loop = false}) async {
  try {
    final audio = _Audio('assets/assets/sounds/$name.wav')..loop = loop;
    if (loop) {
      _looping?.pause();
      _looping = audio;
    }
    await audio.play().toDart;
  } catch (_) {
    // The browser blocks sound until the page is clicked: no sound then.
  }
}

Future<void> webStopSound() async {
  _looping?.pause();
  _looping = null;
}

void windowsPlaySound(String path, {bool loop = false}) {}

void windowsStopSound() {}
