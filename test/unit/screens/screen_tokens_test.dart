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
///
/// F7 widens the scan (D-072): `lib/app.dart`, `lib/main.dart` and
/// `lib/routes` follow the screen rule, and every other folder under `lib/`
/// (blocs, core, data, domain, models, utils) holds no colour or curve at
/// all, so `lib/design_system` is the only place with raw values; its token
/// files are the source of truth and the rest of it only reads them.
/// `Colors.` but not `FpColors.` (a comment may name the token class).
final Matcher noMaterialColors = isNot(
  matches(RegExp(r'(?<![A-Za-z])Colors\.')),
);

void main() {
  final appFiles = [
    File('lib/app.dart'),
    File('lib/main.dart'),
    ...Directory('lib/routes')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart')),
  ];

  final otherLibFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
        (f) =>
            !f.path.startsWith('lib/screens/') &&
            !f.path.startsWith('lib/routes/') &&
            !f.path.startsWith('lib/design_system/') &&
            f.path != 'lib/app.dart' &&
            f.path != 'lib/main.dart',
      )
      .toList();

  final designSystemFiles = Directory('lib/design_system')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('app shell and routes', () {
    for (final file in appFiles) {
      final source = file.readAsStringSync();
      test('${file.path}: no raw colours, curves or motion durations', () {
        expect(source, isNot(contains('Color(0x')), reason: file.path);
        expect(source, noMaterialColors, reason: file.path);
        expect(source, isNot(contains('Curves.')), reason: file.path);
        expect(
          source,
          isNot(matches(RegExp(r'Duration\(\s*(milli|micro)?seconds'))),
          reason: '${file.path} holds a magic duration',
        );
        expect(source, isNot(contains('package:fin_pay/constants/')));
      });
    }
  });

  group('every other lib folder', () {
    test('is populated', () {
      expect(otherLibFiles.length, greaterThan(40));
    });
    for (final file in otherLibFiles) {
      final source = file.readAsStringSync();
      test('${file.path}: no colours or curves', () {
        expect(source, isNot(contains('Color(0x')), reason: file.path);
        expect(source, noMaterialColors, reason: file.path);
        expect(source, isNot(contains('Curves.')), reason: file.path);
      });
    }
  });

  group('design system', () {
    test('only the token and theme files define colours', () {
      final offenders = designSystemFiles
          .where((f) => f.readAsStringSync().contains('Color(0x'))
          .map((f) => f.path)
          .where(
            (path) =>
                !path.startsWith('lib/design_system/tokens/') &&
                !path.startsWith('lib/design_system/theme/'),
          )
          .toList();
      expect(offenders, isEmpty);
    });
    test('only the motion token file defines curves', () {
      final offenders = designSystemFiles
          .where((f) => f.readAsStringSync().contains('Cubic('))
          .map((f) => f.path)
          .where((path) => path != 'lib/design_system/tokens/fp_motion.dart')
          .toList();
      expect(offenders, isEmpty);
    });
  });

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
      expect(source, noMaterialColors, reason: file.path);
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
