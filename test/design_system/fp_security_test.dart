import 'dart:io';

import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump.dart';

/// Regression tests from the F2 security review (docs/SECURITY_REVIEW.md).
void main() {
  group('design system never logs', () {
    test(
      'no print/debugPrint/log/developer.log calls in lib/design_system',
      () {
        final files = Directory('lib/design_system')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        final offenders = <String>[];
        final pattern = RegExp(r'\b(print|debugPrint|log|logger)\s*\(');
        for (final file in files) {
          for (final (i, line) in file.readAsLinesSync().indexed) {
            if (line.trimLeft().startsWith('//')) continue;
            if (pattern.hasMatch(line)) offenders.add('${file.path}:${i + 1}');
          }
        }
        expect(offenders, isEmpty);
      },
    );

    test('FpTextField does not import dart:developer', () {
      final src = File(
        'lib/design_system/components/fp_text_field.dart',
      ).readAsStringSync();
      expect(src, isNot(contains('dart:developer')));
      expect(src, isNot(contains('Clipboard')));
    });
  });

  group('amount text survives hostile values', () {
    for (final value in [
      0,
      -1,
      1,
      99999999999,
      -99999999999,
      9223372036854775807,
      -9223372036854775808,
    ]) {
      testWidgets('paise=$value renders without throwing', (tester) async {
        await pumpFp(tester, FpAmountText(paise: value));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(FpAmountText.format(value), isNotEmpty);
      });
    }

    testWidgets('masked amount exposes nothing in semantics or text', (
      tester,
    ) async {
      await pumpFp(
        tester,
        const FpAmountText(paise: 123456789, hide: FpAmountHide.mask),
      );
      await tester.pump(const Duration(seconds: 1));
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join();
      expect(texts, isNot(contains('1')));
      expect(texts, isNot(contains('9')));
      expect(
        tester.getSemantics(find.byType(FpAmountText)).label,
        'Amount hidden',
      );
    });
  });

  group('gallery', () {
    testWidgets('is empty in release builds even when routed to', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FpTheme.dark(),
          home: const FpGalleryScreen(isRelease: true),
        ),
      );
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });

  group('press guards', () {
    testWidgets('FpPressable fires once per tap even under 200 rapid taps', (
      tester,
    ) async {
      var taps = 0;
      await pumpFp(
        tester,
        FpPressable(
          onPressed: () => taps++,
          child: const SizedBox(width: 60, height: 60),
        ),
      );
      final center = tester.getCenter(find.byType(FpPressable));
      for (var i = 0; i < 200; i++) {
        await tester.tapAt(center);
      }
      await tester.pumpAndSettle();
      // Pressable is feedback only: it has no submit guard, so every tap
      // counts. Submissions must go through FpButton.
      expect(taps, 200);
    });

    testWidgets('a disabled FpToggle ignores 50 rapid taps', (tester) async {
      await pumpFp(tester, const FpToggle(value: false));
      for (var i = 0; i < 50; i++) {
        await tester.tap(find.byType(FpToggle));
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.widget<FpToggle>(find.byType(FpToggle)).value, isFalse);
    });
  });
}
