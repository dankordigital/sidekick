import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidekick/core/client.dart';
import 'package:sidekick/core/errors.dart';

/// Every kind of problem gets a title, a reason in plain words, things to
/// try, and the right button.
void main() {
  Problem explain(Object e, {String? device}) => explainError(e, device: device);

  void expectKind(Problem p, {required String title, ProblemAction? action, Pattern? reason, Pattern? step}) {
    expect(p.title, title);
    expect(p.action, action);
    expect(p.reason, isNotEmpty);
    expect(p.steps.length, inInclusiveRange(1, 3), reason: 'one to three things to try');
    if (reason != null) expect(p.reason, contains(reason));
    if (step != null) expect(p.steps.join(' '), contains(step));
    for (final text in [p.title, p.reason, ...p.steps]) {
      expect(text, isNot(matches(RegExp(r'Exception|SPAKE|socket|HTTP|payload|peer\b|null', caseSensitive: false))));
    }
  }

  test("can't reach the device", () {
    expectKind(
      explain(const SocketException('Connection refused'), device: 'Pixel 9'),
      title: "Can't reach Pixel 9",
      action: ProblemAction.tryAgain,
      step: 'Sidekick is open on Pixel 9',
    );
    expectKind(explain(TimeoutException('x')), title: "Can't reach the other device", action: ProblemAction.tryAgain);
    expectKind(
      explain(SidekickException('Pixel 9 is out of reach.')),
      title: "Can't reach the other device",
      action: ProblemAction.tryAgain,
    );
  });

  test('on different Wi-Fi', () {
    expectKind(
      explain(SidekickException('Pixel 9 is on Wi-Fi too, but not this one. Connect both to the same Wi-Fi.')),
      title: 'On different Wi-Fi',
      action: ProblemAction.tryAgain,
      step: 'Find nearby',
    );
  });

  test('pairing keys no longer match, or the device was reset', () {
    expectKind(
      explain(SidekickException("Pairing keys don't match")),
      title: 'Pair again',
      action: ProblemAction.pairAgain,
    );
    expectKind(
      explain(SidekickException('x', identityChanged: true), device: 'Pixel 9'),
      title: 'Pair again',
      action: ProblemAction.pairAgain,
      reason: 'Pixel 9 was reset',
    );
    expectKind(
      explain(SidekickException('Not paired', status: 401), device: 'Pixel 9'),
      title: 'Not paired anymore',
      action: ProblemAction.pairAgain,
      reason: "Pixel 9 doesn't know this device",
    );
  });

  test('wrong or expired 6-digit code', () {
    expectKind(explain(SidekickException('Wrong code', status: 403)), title: "That code isn't right", step: '6 digits');
    expectKind(
      explain(SidekickException('No open pairing request. Start pairing again.')),
      title: 'The code ran out',
      step: 'Start pairing again',
    );
    expectKind(
      explain(SidekickException('That QR code has expired. Show a new one and scan again.')),
      title: 'The code ran out',
    );
    expectKind(
      explain(SidekickException('Too many pairing requests. Try again in a minute.')),
      title: 'Too many tries',
    );
  });

  test('declined, no answer, already ringing', () {
    expectKind(explain('Pixel 9 declined 3 photos.'), title: 'Declined', action: ProblemAction.tryAgain);
    expectKind(
      explain('No answer from Pixel 9. Nothing was sent.'),
      title: 'No answer',
      action: ProblemAction.tryAgain,
    );
    expectKind(
      explain(SidekickException('Pixel 9 is already being pinged', status: 409)),
      title: 'Already ringing',
      step: 'Found It!',
    );
  });

  test('disk full, folder not allowed, file gone', () {
    expectKind(
      explain(const FileSystemException('x', '/a/b/photo.jpg', OSError('No space left on device', 28))),
      title: 'Not enough space',
      action: ProblemAction.tryAgain,
      step: 'Save received files to',
    );
    expectKind(
      explain(const FileSystemException('x', '/a/b', OSError('Permission denied', 13))),
      title: "Sidekick can't use that",
      reason: '"b"',
    );
    expectKind(
      explain(const FileSystemException('x', '/a/report.pdf', OSError('No such file or directory', 2))),
      title: 'Can\'t find "report.pdf"',
    );
    expectKind(explain(SidekickException('Folder not found', status: 404)), title: 'That folder is gone');
  });

  test('permissions: camera, Bluetooth, local network, photos, Accessibility, notification access', () {
    for (final message in [
      'Sidekick needs the camera to scan codes. Allow it in Settings, or type the 6-digit code instead.',
      "Sidekick isn't allowed to use Bluetooth.",
      'Allow Sidekick to find devices on your local network in Settings → Privacy.',
      'Sidekick needs access to your photos to see new screenshots.',
      'Allow Sidekick in Settings → Accessibility (if it\'s already on there, remove it and add it again).',
      'Allow Sidekick in Notification access, then come back.',
    ]) {
      expectKind(explain(message), title: 'Sidekick needs permission', action: ProblemAction.openSettings);
    }
  });

  test('Bluetooth off, firewall, connection lost, older Sidekick, too big, damaged', () {
    expectKind(
      explain(StateError('Bluetooth is off')),
      title: 'Bluetooth is off',
      action: ProblemAction.turnOnBluetooth,
    );
    expectKind(
      explain(
        "Joined Pixel 9's direct Wi-Fi but couldn't reach it. Check that a firewall on Pixel 9 lets Sidekick through.",
      ),
      title: 'Blocked by a firewall',
      action: ProblemAction.tryAgain,
      step: 'Windows Security',
    );
    expectKind(
      explain(SidekickException('x', connectionLost: true)),
      title: 'The connection dropped',
      action: ProblemAction.tryAgain,
      step: 'carries on',
    );
    expectKind(
      explain('Request failed (400)\nPixel 9 runs an older Sidekick (2.1.0): update it to 3.0.5.'),
      title: 'Update Sidekick',
    );
    expectKind(
      explain(SidekickException('Too large to send over Bluetooth. Use Wi-Fi for big files.')),
      title: 'Too big to send this way',
    );
    expectKind(
      explain(SidekickException('Message failed authentication', status: 401)),
      title: 'Something got damaged on the way',
      action: ProblemAction.tryAgain,
    );
    expectKind(
      explain(SidekickException('This device has turned that feature off', status: 403), device: 'Pixel 9'),
      title: 'Turned off on Pixel 9',
      action: ProblemAction.tryAgain,
      step: 'On Pixel 9',
    );
  });

  test('anything else: calm, and never programmer-speak', () {
    expectKind(
      explain(ArgumentError('No host specified in URI https://:1/x')),
      title: 'Something went wrong',
      action: ProblemAction.tryAgain,
    );
    expect(explain(Exception('Null check operator used on a null value')).reason, 'Something went wrong. Try again.');
    expect(explain(SidekickException('Request failed (500)')).title, "The devices didn't understand each other");
  });

  test('a title from the caller replaces the usual one; the reason stays', () {
    final p = explainError(const SocketException('x'), device: 'Pixel 9', title: "Couldn't send to Pixel 9");
    expect(p.title, "Couldn't send to Pixel 9");
    expect(p.reason, contains("Couldn't reach Pixel 9"));
    expect(describeError(const SocketException('x')), p.reason.replaceAll('Pixel 9', 'the other device'));
  });
}
