import 'package:flutter_test/flutter_test.dart';
import 'package:sidekick/ui/lucide.dart';

void main() {
  test('every design icon draws, inside its 24×24 box', () {
    for (final name in lucide.keys) {
      final bounds = lucidePath(name).getBounds();
      expect(bounds.isEmpty, isFalse, reason: '$name draws nothing');
      expect(bounds.left, greaterThanOrEqualTo(-0.5), reason: name);
      expect(bounds.top, greaterThanOrEqualTo(-0.5), reason: name);
      expect(bounds.right, lessThanOrEqualTo(24.5), reason: name);
      expect(bounds.bottom, lessThanOrEqualTo(24.5), reason: name);
    }
  });
}
