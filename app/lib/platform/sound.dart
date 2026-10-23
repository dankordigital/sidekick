import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'sound_platform.dart' if (dart.library.js_interop) 'sound_platform_web.dart';
import '../core/host.dart';

/// Plays Sidekick's sounds on every platform, with what the system already
/// has: no audio plugin. The sounds come from tool/sounds/ (prepared by
/// tool/prepare_sounds.py): startup, a request arriving, and a request
/// accepted or declined. Settings → Sound turns them all off.
///
/// * Mac: AVAudioPlayer (then NSSound, then `afplay`).
/// * Windows: `PlaySound` from winmm.dll.
/// * iPhone: AVAudioPlayer on the media volume, mixed with other audio.
/// * Android: MediaPlayer on the media volume.
/// * The website's preview (a browser): an HTML audio element.
///
/// Never throws: a missing chime is not worth an error.
Future<void> playStartupSound() => _play('startup');

/// A device wants to send files here (the Accept/Decline card appears).
Future<void> playRequestSound() => _play('request');

/// A request was accepted (tapped here, or the other device's answer).
Future<void> playAcceptSound() => _play('accept');

/// A request was declined (tapped here, or the other device's answer).
Future<void> playDeclineSound() => _play('decline');

/// Another device pinged this one: the ringtone (the owner's, ping.wav) on
/// repeat until [stopPingRingtone] (Found It). Loud, and on Android on the
/// alarm volume, so it's heard even on silent. Plays whatever Settings →
/// Sound says: someone asked for it.
Future<void> startPingRingtone() async {
  if (kIsWeb) return webPlaySound('ping', loop: true);
  try {
    final path = await _soundFile('ping');
    if (Host.isWindows) {
      windowsPlaySound(path, loop: true);
    } else if (_channel case final channel?) {
      await channel.invokeMethod<void>('loopSound', {'path': path});
    }
  } catch (e) {
    debugPrint('Sidekick: ping ringtone failed: $e');
  }
}

/// Found It: the ringtone stops.
Future<void> stopPingRingtone() async {
  if (kIsWeb) return webStopSound();
  try {
    if (Host.isWindows) {
      windowsStopSound();
    } else if (_channel case final channel?) {
      await channel.invokeMethod<void>('stopLoop');
    }
  } catch (e) {
    debugPrint('Sidekick: stopping the ping ringtone failed: $e');
  }
}

/// The platform channel with `loopSound` / `stopLoop` (not Windows).
MethodChannel? get _channel => Host.isMacOS
    ? const MethodChannel('sidekick/macos')
    : Host.isIOS
    ? const MethodChannel('sidekick/ios')
    : Host.isAndroid
    ? const MethodChannel('sidekick/android')
    : null;

Future<void> _play(String name) async {
  if (kIsWeb) return webPlaySound(name);
  try {
    final path = await _soundFile(name);
    if (Host.isMacOS) {
      var played = false;
      try {
        played = await const MethodChannel('sidekick/macos').invokeMethod<bool>('playSound', {'path': path}) ?? false;
      } catch (_) {}
      if (!played) await Process.start('/usr/bin/afplay', [path], mode: ProcessStartMode.detached);
    } else if (Host.isWindows) {
      windowsPlaySound(path);
    } else if (Host.isIOS) {
      await const MethodChannel('sidekick/ios').invokeMethod('playSound', {'path': path});
    } else if (Host.isAndroid) {
      await const MethodChannel('sidekick/android').invokeMethod('playSound', {'path': path});
    }
  } catch (e) {
    // No sound, no problem; but say why in the log.
    debugPrint('Sidekick: $name sound failed: $e');
  }
}

/// The sound as a file the system players can open (written once).
Future<String> _soundFile(String name) async {
  final data = await rootBundle.load('assets/sounds/$name.wav');
  final file = File(p.join((await _soundDir()).path, 'sidekick-$name.wav'));
  if (!file.existsSync() || file.lengthSync() != data.lengthInBytes) {
    await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
  }
  return file.path;
}

/// Where the sound files go. On the Mac the "temporary" directory is
/// `~/Library/Caches/<app id>`, which nothing creates: writing there failed,
/// so the Mac never played a sound. Created here, with the system's temp
/// folder if even that fails.
Future<Directory> _soundDir() async {
  try {
    return await (await getTemporaryDirectory()).create(recursive: true);
  } catch (_) {
    return Directory.systemTemp;
  }
}
