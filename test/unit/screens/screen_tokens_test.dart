import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every screen draws with `context.fp` tokens and `Fp*` components: no raw
/// colours, motion durations or curves outside the design system, and no
/// import of the deleted legacy widgets or of chart/NeoPOP packages that
/// the design system wraps (F6, spec §4 "no raw hex colors, magic durations
/// or ad-hoc curves in screen code").
///
/// Pure logic files (cubits, state machines, maths, rules) may hold
/// non-motion durations such as ledger timeouts; they carry no colours or
/// curves either.
void main() {
  final screenFiles = Directory('lib/screens')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  bool isPureLogic(String path) =>
      path.endsWith('_cubit.dart') ||
      path.endsWith('_state.dart') ||
      path.endsWith('_math.dart') ||
      path.endsWith('_machine.dart') ||
      path.endsWith('_rules.dart') ||
      path.endsWith('_input.dart') ||
      path.endsWith('_search.dart') ||
      path.endsWith('_receipt.dart') ||
      path.endsWith('_draft.dart') ||
      path.contains('/transfer/transfer/') ||
      path.contains('/transfer/payment/');

  test('the screen tree is populated', () {
    expect(screenFiles.length, greaterThan(40));
  });

  for (final file in screenFiles) {
    final source = file.readAsStringSync();
    final lines = source.split('\n');

    test('${file.path}: no raw colours or curves', () {
      expect(source, isNot(contains('Color(0x')), reason: file.path);
      expect(source, isNot(contains('Colors.')), reason: file.path);
      expect(source, isNot(contains('Curves.')), reason: file.path);
    });

    test('${file.path}: no legacy or wrapped package imports', () {
      expect(source, isNot(contains('package:fin_pay/widgets/')));
      expect(source, isNot(contains('package:fin_pay/services/')));
      expect(source, isNot(contains('package:neopop/')));
      expect(source, isNot(contains('package:shimmer/')));
      expect(source, isNot(contains('flutter_staggered_animations')));
    });

    if (!isPureLogic(file.path)) {
      test('${file.path}: no magic motion durations', () {
        final motion = RegExp(r'Duration\(\s*(milli|micro)?seconds');
        final offenders = <String>[];
        for (final (i, line) in lines.indexed) {
          if (!motion.hasMatch(line)) continue;
          // Timeouts are not motion; they are the only Duration literals a
          // screen may hold, and must say so on the line.
          if (line.toLowerCase().contains('timeout')) continue;
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
        expect(offenders, isEmpty);
      });
    }
  }
}
