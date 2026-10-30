import 'dart:math';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

/// Controlled-value harness: stores the value like a screen would.
class _Harness extends StatefulWidget {
  const _Harness({
    this.error = false,
    this.enabled = true,
    this.haptics,
    this.onCompleted,
    this.log,
  });

  final bool error;
  final bool enabled;
  final HapticService? haptics;
  final ValueChanged<String>? onCompleted;
  final List<String>? log;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String value = '';

  @override
  Widget build(BuildContext context) => FpOtpField(
    value: value,
    error: widget.error,
    enabled: widget.enabled,
    haptics: widget.haptics,
    onCompleted: widget.onCompleted,
    onChanged: (v) {
      widget.log?.add(v);
      setState(() => value = v);
    },
  );
}

Finder _editable() => find.byType(EditableText);

Color _cellBorder(WidgetTester tester, int index) {
  final box = tester.widget<AnimatedContainer>(
    find.byKey(ValueKey('fp-otp-cell-$index')),
  );
  return (box.decoration! as BoxDecoration).border!.top.color;
}

void main() {
  group('FpOtpField', () {
    testWidgets('renders six cells and a labelled text-field node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpFp(tester, const _Harness());
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('fp-otp-cell-$i')), findsOneWidget);
      }
      final node = tester.getSemantics(find.byType(FpOtpField));
      expect(node.label, 'Verification code');
      expect(node.value, '0 of 6 digits entered');
      handle.dispose();
    });

    testWidgets('typing fills cells in order and the active cell advances', (
      tester,
    ) async {
      final log = <String>[];
      await pumpFp(tester, _Harness(log: log));
      await tester.tap(find.byKey(const ValueKey('fp-otp-cell-0')));
      await tester.pump();
      await tester.enterText(_editable(), '1');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('1'), findsWidgets);
      expect(_cellBorder(tester, 1), FpColors.accent);
      expect(_cellBorder(tester, 0), FpColors.border);
      await tester.enterText(_editable(), '12');
      await tester.pump(const Duration(milliseconds: 200));
      expect(_cellBorder(tester, 2), FpColors.accent);
      expect(log, ['1', '12']);
      final node = tester.getSemantics(find.byType(FpOtpField));
      expect(node.value, '2 of 6 digits entered');
    });

    testWidgets('paste: non-digits are stripped, six digits complete', (
      tester,
    ) async {
      final log = <String>[];
      String? completed;
      await pumpFp(
        tester,
        _Harness(log: log, onCompleted: (v) => completed = v),
      );
      await tester.enterText(_editable(), 'Your code: 24-68-10, thanks 99');
      await tester.pump();
      expect(log.last, '246810');
      expect(completed, '246810');
    });

    testWidgets('backspace moves back one cell', (tester) async {
      final log = <String>[];
      await pumpFp(tester, _Harness(log: log));
      await tester.enterText(_editable(), '123');
      await tester.pump();
      await tester.enterText(_editable(), '12');
      await tester.pump(const Duration(milliseconds: 200));
      expect(log, ['123', '12']);
      expect(_cellBorder(tester, 2), FpColors.accent);
    });

    testWidgets('a new error shakes, flashes red and plays the error haptic', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      await pumpFp(tester, _Harness(haptics: haptics));
      final shake = tester.widget<FpShake>(find.byType(FpShake));
      expect(shake.controller.shakeCount, 0);
      await pumpFp(tester, _Harness(haptics: haptics, error: true));
      await tester.pump();
      expect(shake.controller.shakeCount, 1);
      expect(haptics.calls, contains(HapticType.error));
      expect(_cellBorder(tester, 0), FpColors.alert);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce motion: error state still shows, no shake movement', (
      tester,
    ) async {
      await pumpFp(tester, const _Harness(error: true), reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_cellBorder(tester, 0), FpColors.alert);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled: input is ignored', (tester) async {
      final log = <String>[];
      await pumpFp(tester, _Harness(log: log, enabled: false));
      await tester.enterText(_editable(), '123');
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('digit entry plays a selection haptic', (tester) async {
      final haptics = fakeHaptics();
      await pumpFp(tester, _Harness(haptics: haptics));
      await tester.enterText(_editable(), '1');
      await tester.pump();
      expect(haptics.calls, [HapticType.selection]);
    });

    testWidgets('1,000 random junk inputs never throw, value stays ≤ 6', (
      tester,
    ) async {
      final log = <String>[];
      await pumpFp(tester, _Harness(log: log));
      final rng = Random(3);
      const alphabet = '0123456789abc 😀\u202E-+()٣٤\n<>;\'"%';
      final runes = alphabet.runes.toList();
      for (var i = 0; i < 1000; i++) {
        final raw = String.fromCharCodes(
          List.generate(
            rng.nextInt(20),
            (_) => runes[rng.nextInt(runes.length)],
          ),
        );
        await tester.enterText(_editable(), raw);
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final v in log) {
        expect(v.length, lessThanOrEqualTo(6));
        expect(RegExp(r'^[0-9]*$').hasMatch(v), isTrue);
      }
    });

    testWidgets('meets tap target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpFp(tester, const _Harness());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
