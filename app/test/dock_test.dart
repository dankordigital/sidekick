import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sidekick/ui/dock.dart';

void main() {
  const items = [
    DockItem(icon: Icons.devices_outlined, selectedIcon: Icons.devices, label: 'Devices'),
    DockItem(icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, label: 'Chat'),
    DockItem(icon: Icons.upload_outlined, selectedIcon: Icons.upload, label: 'Send'),
    DockItem(icon: Icons.mouse_outlined, selectedIcon: Icons.mouse, label: 'Remote'),
    DockItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  Future<List<int>> run(WidgetTester tester, Future<void> Function() act) async {
    final picked = <int>[];
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.all(16),
              child: FloatingDock(
                items: items,
                index: index,
                onTap: (i) => setState(() {
                  picked.add(i);
                  index = i;
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('tapping a tab picks it', (tester) async {
    final picked = await run(tester, () => tester.tap(find.bySemanticsLabel('Remote')));
    expect(picked, [3]);
  });

  testWidgets('sliding a finger along the dock picks each tab it passes', (tester) async {
    final picked = await run(tester, () async {
      final from = tester.getCenter(find.bySemanticsLabel('Devices'));
      final to = tester.getCenter(find.bySemanticsLabel('Settings'));
      final g = await tester.startGesture(from);
      for (var i = 1; i <= 20; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 20)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
    });
    expect(picked.first, 1);
    expect(picked.last, 4);
  });
}
