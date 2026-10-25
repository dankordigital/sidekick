import 'dart:async';
import 'dart:io';

import 'client.dart';

/// What went wrong, in words for people: never a stack of exception text
/// ("SocketException: OS Error…", "Invalid argument(s): No host…").
String describeError(Object error) {
  switch (error) {
    case SidekickException(:final message):
      return message;
    case SocketException() || HttpException() || HandshakeException():
      return "Couldn't reach the other device. Make sure Sidekick is open on it and both are on the same Wi-Fi.";
    case TimeoutException():
      return 'The other device took too long to answer. Try again.';
    case FileSystemException(:final path, :final osError):
      final what = path == null || path.isEmpty ? 'a file' : '"${path.split(RegExp(r'[/\\]')).last}"';
      final why = osError?.message.trim() ?? '';
      if (osError?.errorCode == 28 || why.toLowerCase().contains('space')) {
        return 'There isn\'t enough space here.';
      }
      if (why.toLowerCase().contains('permission') || osError?.errorCode == 13 || osError?.errorCode == 5) {
        return 'Sidekick isn\'t allowed to use $what.';
      }
      return "Couldn't use $what${why.isEmpty ? '' : ' ($why)'}.";
    default:
      // Flutter's PlatformException (not imported here: core stays
      // platform-independent): "PlatformException(code, message, …)".
      final platform = RegExp(r'^PlatformException\([^,]*, ([^,]+),').firstMatch('$error');
      if (platform != null && platform.group(1) != 'null') return platform.group(1)!.trim();
      final text = '$error'
          .replaceFirst(RegExp(r'^(Exception|Bad state|Invalid argument\(s\)|FormatException|StateError): ?'), '')
          .trim();
      // Programmer-speak (a URI, a type name) helps nobody: say something useful.
      if (text.isEmpty || RegExp(r'https?://|Instance of|Null check|type .* is not a subtype').hasMatch(text)) {
        return 'Something went wrong. Try again.';
      }
      return text;
  }
}
