import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sidekick/core/client.dart';
import 'package:sidekick/ui/notices.dart';
import 'package:sidekick/ui/widgets.dart';

/// Successes: a notice that goes by itself, its bar showing the time left.
/// Problems: a pop-up with Close.
void main() {
  setUp(NoticeCenter.instance.clear);

  Widget app({Widget? home}) => MaterialApp(
    builder: (context, child) => NoticeArea(child: child!),
    home: home ?? const Scaffold(body: SizedBox.expand()),
  );

  double barWidth(WidgetTester tester) =>
      tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor ?? 0;

  testWidgets('a notice goes by itself after 5 seconds, its bar emptying', (tester) async {
    await tester.pumpWidget(app());
    showNotice('Sent 3 photos to Pixel 9');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sent 3 photos to Pixel 9'), findsOneWidget);
    final start = barWidth(tester);
    await tester.pump(const Duration(seconds: 2));
    final later = barWidth(tester);
    expect(later, lessThan(start));
    expect(later, closeTo(0.55, 0.1), reason: 'about 2 of 5 seconds gone');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Sent 3 photos to Pixel 9'), findsNothing);
  });

  testWidgets('never longer than 10 seconds', (tester) async {
    expect(NoticeData('x', duration: const Duration(minutes: 1)).duration, maxNoticeDuration);
    await tester.pumpWidget(app());
    showNotice('Long one', duration: const Duration(seconds: 30));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('Long one'), findsNothing);
  });

  testWidgets('hovering pauses it; leaving lets it go on', (tester) async {
    await tester.pumpWidget(app());
    showNotice('Paired with MacBook Pro');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Paired with MacBook Pro')));
    await tester.pump();
    final held = barWidth(tester);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Paired with MacBook Pro'), findsOneWidget, reason: 'paused while the pointer is on it');
    expect(barWidth(tester), held);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Paired with MacBook Pro'), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('its button does the thing and closes it; ✕ closes it', (tester) async {
    var opened = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app());
    showNotice('Received report.pdf', actionLabel: 'Show in folder', onAction: () => opened++);
    showNotice('Copied');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Show in folder'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, 1);
    expect(find.text('Received report.pdf'), findsNothing);
    // Screen readers read it out, and its ✕ is a button of its own.
    expect(find.bySemanticsLabel('Copied'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Close')),
      matchesSemantics(label: 'Close', isButton: true, hasTapAction: true),
    );
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Copied'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a few stack, the rest wait their turn', (tester) async {
    await tester.pumpWidget(app());
    for (var i = 1; i <= 5; i++) {
      showNotice('Notice $i');
    }
    await tester.pump();
    expect(find.byType(NoticeCard), findsNWidgets(NoticeCenter.maxShown));
    expect(find.text('Notice 4'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Notice 4'), findsOneWidget);
    expect(find.text('Notice 5'), findsOneWidget);
  });

  testWidgets('reduced motion: no sliding, the bar still runs', (tester) async {
    await tester.pumpWidget(MediaQuery(data: const MediaQueryData(disableAnimations: true), child: app()));
    showNotice('Saved IMG_2042.HEIC');
    await tester.pump();
    final offset = tester.widget<Transform>(
      find.ancestor(of: find.text('Saved IMG_2042.HEIC'), matching: find.byType(Transform)).first,
    );
    expect(offset.transform.getTranslation().y, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(barWidth(tester), lessThan(1));
  });

  group('errors', () {
    Widget page(void Function(BuildContext) onTap) => app(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(onPressed: () => onTap(context), child: const Text('go')),
          ),
        ),
      ),
    );

    testWidgets('a pop-up: what went wrong, why, numbered things to try, Close', (tester) async {
      await tester.pumpWidget(
        page((c) => showError(c, SidekickException('x', connectionLost: true), title: "Couldn't send to Pixel 9")),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text("Couldn't send to Pixel 9"), findsOneWidget);
      expect(find.textContaining('stopped answering'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('Try again'), findsNothing, reason: 'no retry given: no button for it');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Try again does it again', (tester) async {
      var tries = 0;
      await tester.pumpWidget(page((c) => showError(c, TimeoutException('slow'), onRetry: () => tries++)));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(tries, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Enter and Esc close it', (tester) async {
      await tester.pumpWidget(page((c) => showError(c, 'That folder has no files in it.', title: 'Nothing to send')));
      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.escape]) {
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        expect(find.text('Nothing to send'), findsOneWidget);
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing, reason: '$key closes it');
      }
    });

    testWidgets('the same problem twice: one pop-up', (tester) async {
      await tester.pumpWidget(
        page((c) {
          showError(c, 'Pixel 9 declined 2 files.');
          showError(c, 'Pixel 9 declined 2 files.');
        }),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });
}
