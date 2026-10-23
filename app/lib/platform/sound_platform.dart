// Windows' PlaySound (winmm.dll) through dart:ffi, for sound.dart. Its own
// file so the browser preview (no dart:ffi) can leave it out; see
// sound_platform_web.dart.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _PlaySoundNative = Int32 Function(Pointer<Utf16> sound, IntPtr module, Uint32 flags);
typedef _PlaySoundDart = int Function(Pointer<Utf16> sound, int module, int flags);

/// Kept for the life of the app: an asynchronous PlaySound may still be
/// reading the name after the call returns.
final Map<String, Pointer<Utf16>> _windowsPaths = {};

final _windowsPlaySound = DynamicLibrary.open('winmm.dll')
    .lookupFunction<_PlaySoundNative, _PlaySoundDart>('PlaySoundW');

/// Plays the WAV at [path], once or (with [loop]) until [windowsStopSound].
void windowsPlaySound(String path, {bool loop = false}) {
  const sndAsync = 0x0001, sndNoDefault = 0x0002, sndLoop = 0x0008, sndFilename = 0x00020000;
  _windowsPlaySound(
    _windowsPaths[path] ??= path.toNativeUtf16(),
    0,
    sndFilename | sndAsync | sndNoDefault | (loop ? sndLoop : 0),
  );
}

void windowsStopSound() => _windowsPlaySound(nullptr, 0, 0);

// Only the browser preview plays sounds this way.
Future<void> webPlaySound(String name, {bool loop = false}) async {}

Future<void> webStopSound() async {}
