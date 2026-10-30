import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeHapticService', () {
    test('records every call in order', () async {
      final haptics = FakeHapticService();

      await haptics.light();
      await haptics.heavy();
      await haptics.success();

      expect(haptics.calls, [
        HapticType.light,
        HapticType.heavy,
        HapticType.success,
      ]);
    });

    test('play dispatches by type', () async {
      final haptics = FakeHapticService();

      for (final type in HapticType.values) {
        await haptics.play(type);
      }

      expect(haptics.calls, HapticType.values);
    });

    test('reset clears the recording', () async {
      final haptics = FakeHapticService()
        ..calls.add(HapticType.error)
        ..reset();

      expect(haptics.calls, isEmpty);
    });
  });
}
