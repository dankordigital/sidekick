import 'dart:async';
import 'dart:io';

import 'client.dart';
import 'host.dart';

/// A button that can fix the problem, next to Close in the error pop-up.
enum ProblemAction {
  /// Do the same thing again (the caller says how).
  tryAgain('Try again'),

  /// The pairing no longer works on one side: pair the two again.
  pairAgain('Pair again'),

  /// Bluetooth is off in Sidekick or on the device.
  turnOnBluetooth('Turn on Bluetooth'),

  /// A permission is missing: the system's settings for Sidekick.
  openSettings('Open Settings');

  const ProblemAction(this.label);
  final String label;
}

/// What went wrong, for people: a title ("Couldn't send to Pixel 9"), why,
/// and one to three things to try. Shown by `showError` (ui/widgets.dart).
class Problem {
  const Problem({required this.title, required this.reason, this.steps = const [], this.action});

  final String title;
  final String reason;
  final List<String> steps;
  final ProblemAction? action;

  Problem withTitle(String? title) =>
      title == null ? this : Problem(title: title, reason: reason, steps: steps, action: action);
}

/// What went wrong, in one sentence for people: never a stack of exception
/// text ("SocketException: OS Error…", "Invalid argument(s): No host…").
String describeError(Object error) => explainError(error).reason;

/// What went wrong, why, and what to try. [device] names the other device
/// when there is one ("Can't reach Pixel 9"); [title] replaces the usual
/// title ("Couldn't send to Pixel 9").
Problem explainError(Object error, {String? device, String? title}) =>
    _explain(error, device ?? 'the other device').withTitle(title);

Problem _explain(Object error, String device) {
  final other = device;
  final cap = other[0].toUpperCase() + other.substring(1);
  switch (error) {
    case SidekickException(identityChanged: true):
      return Problem(
        title: 'Pair again',
        reason: '$cap was reset or reinstalled, so the old pairing no longer works.',
        steps: ['Pair the two devices again. It takes a few seconds.'],
        action: ProblemAction.pairAgain,
      );
    case SidekickException(connectionLost: true):
      return _dropped(cap);
    case SidekickException(:final message, :final status):
      return _fromMessage(message, other, status: status) ?? Problem(title: 'Something went wrong', reason: message);
    case SocketException() || HttpException() || HandshakeException():
      return _unreachable(other);
    case TimeoutException():
      return Problem(
        title: "Can't reach ${_name(other)}",
        reason: '$cap took too long to answer.',
        steps: _reachSteps(other),
        action: ProblemAction.tryAgain,
      );
    case FileSystemException(:final path, :final osError):
      final what = path == null || path.isEmpty ? 'a file' : '"${path.split(RegExp(r'[/\\]')).last}"';
      final why = osError?.message.trim() ?? '';
      if (osError?.errorCode == 28 || osError?.errorCode == 112 || why.toLowerCase().contains('space')) {
        return const Problem(
          title: 'Not enough space',
          reason: "There isn't enough space here.",
          steps: [
            "Delete files you don't need, then try again.",
            'Or pick another place in Settings → Save received files to.',
          ],
          action: ProblemAction.tryAgain,
        );
      }
      if (why.toLowerCase().contains('permission') || osError?.errorCode == 13 || osError?.errorCode == 5) {
        return Problem(
          title: "Sidekick can't use that",
          reason: 'Sidekick isn\'t allowed to use $what.',
          steps: const [
            'Pick another folder in Settings → Save received files to.',
            'Or give Sidekick access to that folder in your system settings.',
          ],
        );
      }
      if (osError?.errorCode == 2 || why.toLowerCase().contains('no such file')) {
        return Problem(
          title: "Can't find $what",
          reason: "$what isn't there anymore: it may have been moved or deleted.",
          steps: const ['Pick it again from where it is now.'],
        );
      }
      return Problem(
        title: "Couldn't use $what",
        reason: "Couldn't use $what${why.isEmpty ? '' : ' ($why)'}.",
        steps: const ['Check that it is still there and not open in another app, then try again.'],
        action: ProblemAction.tryAgain,
      );
    default:
      // Flutter's PlatformException (not imported here: core stays
      // platform-independent): "PlatformException(code, message, …)".
      final platform = RegExp(r'^PlatformException\([^,]*, ([^,]+),').firstMatch('$error');
      final text = platform != null && platform.group(1) != 'null'
          ? platform.group(1)!.trim()
          : '$error'
                .replaceFirst(RegExp(r'^(Exception|Bad state|Invalid argument\(s\)|FormatException|StateError): ?'), '')
                .trim();
      // Programmer-speak (a URI, a type name) helps nobody: say something useful.
      if (text.isEmpty || RegExp(r'https?://|Instance of|Null check|type .* is not a subtype').hasMatch(text)) {
        return _unknown;
      }
      return _fromMessage(text, other) ?? Problem(title: 'Something went wrong', reason: text);
  }
}

const _unknown = Problem(
  title: 'Something went wrong',
  reason: 'Something went wrong. Try again.',
  steps: ['Try again.', 'If it keeps happening, quit Sidekick and open it again.'],
  action: ProblemAction.tryAgain,
);

String _name(String device) => device == 'the other device' ? 'the other device' : device;

List<String> _reachSteps(String other) => [
  'Check that Sidekick is open on $other.',
  'Put both devices on the same Wi-Fi.',
  if (Host.isWindows)
    'Still nothing? Allow Sidekick through Windows Firewall (Windows Security → Firewall → Allow an app).'
  else
    'No shared Wi-Fi? Turn on Bluetooth in Settings on both, then tap Find nearby.',
];

Problem _unreachable(String other) => Problem(
  title: "Can't reach ${_name(other)}",
  reason: "Couldn't reach $other. Make sure Sidekick is open on it and both are on the same Wi-Fi.",
  steps: _reachSteps(other),
  action: ProblemAction.tryAgain,
);

Problem _dropped(String other) => Problem(
  title: 'The connection dropped',
  reason: '$other stopped answering part-way.',
  steps: const ['Keep the devices close and on the same Wi-Fi.', 'Send again: Sidekick carries on where it stopped.'],
  action: ProblemAction.tryAgain,
);

/// Messages from Sidekick itself, this device's or the other one's (older
/// devices send the same words, so they're recognised, not changed).
Problem? _fromMessage(String message, String other, {int? status}) {
  final m = message.toLowerCase();
  final cap = other[0].toUpperCase() + other.substring(1);
  bool has(String s) => m.contains(s);

  if (has('not this one') || has('different wi-fi')) {
    return Problem(
      title: 'On different Wi-Fi',
      reason: message,
      steps: const [
        'Connect both devices to the same Wi-Fi.',
        'Or tap Find nearby: Sidekick links them directly, no router needed.',
      ],
      action: ProblemAction.tryAgain,
    );
  }
  if (has('pairing keys don') || has('pair again') || has('pair your devices again') || has('pair it again')) {
    return Problem(
      title: 'Pair again',
      reason: message,
      steps: const ['Pair the two devices again. It takes a few seconds.'],
      action: ProblemAction.pairAgain,
    );
  }
  // Bluetooth answers a damaged message with 401 too: not a pairing problem.
  if (has('failed authentication') || has('damaged')) {
    return Problem(
      title: 'Something got damaged on the way',
      reason: 'A piece of it arrived damaged, so Sidekick threw it away.',
      steps: const ['Try again. Over Bluetooth, keeping the devices close helps.'],
      action: ProblemAction.tryAgain,
    );
  }
  if (status == 401 || m == 'not paired' || has('not paired with')) {
    return Problem(
      title: 'Not paired anymore',
      reason: "$cap doesn't know this device anymore: it was unpaired or reset there.",
      steps: const ['Pair the two devices again. It takes a few seconds.'],
      action: ProblemAction.pairAgain,
    );
  }
  if (m == 'wrong code' || has("not the code") || has('wrong one')) {
    return Problem(
      title: "That code isn't right",
      reason: m == 'wrong code' ? "That isn't the code $other is showing." : message,
      steps: const [
        'Check the 6 digits on the other device and type them again.',
        'Each pairing gets a new code: use the one showing now.',
      ],
    );
  }
  if (has('no open pairing request') || has('expired') || has('stopped pairing') || has('start pairing again')) {
    return Problem(
      title: 'The code ran out',
      reason: m.startsWith('no open pairing') ? 'That code is no longer open.' : message,
      steps: const ['Codes work once, for 5 minutes. Start pairing again to get a new one.'],
    );
  }
  if (has('too many pairing')) {
    return Problem(title: 'Too many tries', reason: message, steps: const ['Wait a minute, then pair again.']);
  }
  if (has('already being pinged')) {
    return Problem(
      title: 'Already ringing',
      reason: message,
      steps: const ['Wait until someone taps Found It! on it, then ping again.'],
    );
  }
  if (has('declined')) {
    return Problem(
      title: 'Declined',
      reason: message,
      steps: ['Ask whoever has $other to tap Accept, then send again.'],
      action: ProblemAction.tryAgain,
    );
  }
  if (has('no answer')) {
    return Problem(
      title: 'No answer',
      reason: message,
      steps: ['Ask whoever has $other to tap Accept, then send again.'],
      action: ProblemAction.tryAgain,
    );
  }
  if (has('update sidekick') || has('older sidekick') || has('needs version') || has('runs an older')) {
    return Problem(
      title: 'Update Sidekick',
      reason: message,
      steps: const ['Install the newest Sidekick on both devices (getsidekick.app), then try again.'],
    );
  }
  if (has('turned that feature off') || has("hasn't allowed") || has("doesn't allow")) {
    return Problem(
      title: 'Turned off on ${_name(other)}',
      reason: m == 'this device has turned that feature off' ? '$cap has that turned off.' : message,
      steps: ['On $other, open Sidekick → Settings → What paired devices can do here, and turn it on.'],
      action: ProblemAction.tryAgain,
    );
  }
  if (has('bluetooth is off') || has('turn on bluetooth')) {
    return Problem(
      title: 'Bluetooth is off',
      reason: message,
      steps: const ['Turn on Bluetooth, on this device and in Sidekick → Settings → Bluetooth.'],
      action: ProblemAction.turnOnBluetooth,
    );
  }
  for (final (word, what) in const [
    ('camera', 'the camera'),
    ('bluetooth', 'Bluetooth'),
    ('local network', 'the local network'),
    ('photos', 'your photos'),
    ('accessibility', 'Accessibility'),
    ('notification access', 'Notification access'),
  ]) {
    if (has(word) && (has('allow') || has('permission') || has('needs access') || has('needs the'))) {
      return Problem(
        title: 'Sidekick needs permission',
        reason: message,
        steps: ['Open your settings, find Sidekick and allow $what.', 'Then come back and try again.'],
        action: ProblemAction.openSettings,
      );
    }
  }
  if (has('firewall')) {
    return Problem(
      title: 'Blocked by a firewall',
      reason: message,
      steps: const [
        'On a Windows PC: Windows Security → Firewall → Allow an app → tick Sidekick for Private networks.',
        'Then try again.',
      ],
      action: ProblemAction.tryAgain,
    );
  }
  if (has("couldn't reach") || has("can't reach") || has('out of reach') || has('connection lost')) {
    return Problem(
      title: "Can't reach ${_name(other)}",
      reason: message,
      steps: _reachSteps(other),
      action: ProblemAction.tryAgain,
    );
  }
  if (has('interrupted') || has('cut off')) {
    return _dropped(cap).withTitle('The transfer stopped');
  }
  if (has('too large') || has('too big') || has('too long')) {
    return Problem(
      title: 'Too big to send this way',
      reason: message,
      steps: const ['Put both devices on the same Wi-Fi: big files go fast there.'],
    );
  }
  if (has('folder not found') || has('file not found')) {
    return Problem(
      title: m.startsWith('folder') ? 'That folder is gone' : 'That file is gone',
      reason: m.startsWith('folder')
          ? "That folder isn't there anymore: it was moved or deleted."
          : "That file isn't there anymore: it was moved or deleted.",
      steps: const ['Go back and open the folder again.'],
    );
  }
  if (has('missing ') || has('bad ') || has('expected a json') || has('request failed')) {
    return Problem(
      title: "The devices didn't understand each other",
      reason: '$cap answered in a way this Sidekick didn\'t expect.',
      steps: const ['Install the newest Sidekick on both devices (getsidekick.app), then try again.'],
      action: ProblemAction.tryAgain,
    );
  }
  return null;
}
