import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The insights and activity screens show totals, counterparties and
/// amounts; none of their files may print or log (a debug log on a shared
/// device is a leak), and their states print counts only (checked in the
/// cubit tests' `toString` cases).
void main() {
  final files = [
    for (final dir in [
      'lib/screens/statistics',
      'lib/screens/transactions',
      'lib/screens/notifications',
      'lib/screens/profile',
    ])
      ...Directory(dir).listSync(recursive: true),
    File('lib/design_system/components/fp_swipe_action_row.dart'),
  ].whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  test('the F6 feature files exist', () {
    expect(files.length, greaterThanOrEqualTo(9));
  });

  for (final file in files) {
    test('${file.path} never prints or logs', () {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('print(')), reason: file.path);
      expect(source, isNot(contains('debugPrint(')), reason: file.path);
      expect(source, isNot(contains('Logger.')), reason: file.path);
      expect(source, isNot(contains('developer.log(')), reason: file.path);
      expect(source, isNot(contains('Clipboard')), reason: file.path);
    });
  }
}
