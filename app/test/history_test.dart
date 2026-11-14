import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sidekick/core/history.dart';

void main() {
  group('sixDigitCode', () {
    test('finds 6-digit verification codes', () {
      expect(sixDigitCode('482913'), '482913');
      expect(sixDigitCode('482 913'), '482913');
      expect(sixDigitCode('Your Google verification code is 482913'), '482913');
      expect(sixDigitCode('G-482913 is your Google code'), '482913');
      expect(sixDigitCode('Your code: 482-913'), '482913');
      expect(sixDigitCode('Kod BLIK 123456'), '123456');
    });
    test('leaves everything else alone', () {
      expect(sixDigitCode('Door code 4417'), isNull);
      expect(sixDigitCode('Your verification code: 12345678'), isNull);
      expect(sixDigitCode('Order 123456 shipped'), isNull);
      expect(sixDigitCode('Call me at 555-123-456'), isNull);
      expect(sixDigitCode('Meet at 10:30'), isNull);
    });
  });

  test('kinds by name and text', () {
    expect(historyKindOf('Beach day.JPG'), HistoryKind.photo);
    expect(historyKindOf('Trip.mov'), HistoryKind.video);
    expect(historyKindOf('Boarding pass.pdf'), HistoryKind.file);
    expect(historyKindOf('README'), HistoryKind.file);
    expect(HistoryItem.text(device: 'd', fromMe: false, text: 'https://bbcgoodfood.com/x').kind, HistoryKind.link);
    expect(HistoryItem.text(device: 'd', fromMe: false, text: 'look: https://x.com').kind, HistoryKind.note);
    expect(HistoryItem.text(device: 'd', fromMe: false, text: 'Your code is 482913').code, '482913');
    expect(HistoryItem.text(device: 'd', fromMe: true, text: 'Your code is 482913').code, isNull);
  });

  test('adds, removes, caps and forgets', () {
    final h = History(null);
    for (var i = 0; i < History.perDevice + 5; i++) {
      h.add(HistoryItem.file(device: 'mac', fromMe: false, name: 'f$i.txt', size: i));
    }
    final list = h.forDevice('mac');
    expect(list.length, History.perDevice);
    expect(list.first.name, 'f5.txt');
    expect(h.last('mac')!.name, 'f${History.perDevice + 4}.txt');
    expect(h.remove('mac', list.first.id), isTrue);
    expect(h.remove('mac', 'nope'), isFalse);
    expect(h.forDevice('mac').length, History.perDevice - 1);
    h.forget('mac');
    expect(h.forDevice('mac'), isEmpty);
    expect(h.last('mac'), isNull);
  });

  test('saves and loads, in order', () async {
    final dir = await Directory.systemTemp.createTemp('history_test');
    final file = File('${dir.path}/history.json');
    final h = History(file);
    final t = DateTime(2026, 11, 14, 9, 14);
    h.add(HistoryItem.text(device: 'pixel', fromMe: true, text: 'Door code 4417', at: t));
    h.add(
      HistoryItem.file(
        device: 'pixel',
        fromMe: false,
        name: 'Beach.jpg',
        size: 4800000,
        path: '/x',
        at: t.add(const Duration(minutes: 1)),
      ),
    );
    h.add(HistoryItem.text(device: 'mac', fromMe: false, text: 'https://example.com', at: t));
    await h.save();
    final again = History(file);
    await again.load();
    expect(again.forDevice('pixel').map((i) => i.kind), [HistoryKind.note, HistoryKind.photo]);
    expect(again.forDevice('pixel').last.size, 4800000);
    expect(again.forDevice('pixel').last.path, '/x');
    expect(again.forDevice('pixel').first.fromMe, isTrue);
    expect(again.forDevice('mac').single.kind, HistoryKind.link);
    // A damaged file starts over instead of failing.
    await file.writeAsString('{not json');
    final broken = History(file);
    await broken.load();
    expect(broken.forDevice('pixel'), isEmpty);
    await dir.delete(recursive: true);
  });
}
