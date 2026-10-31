import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Payment code must never print: an amount, a VPA or an idempotency key in
/// a debug log is a leak on a shared device. The blocs log only their
/// failure messages through `Logger`, which is silent in release.
void main() {
  final files = [
    ...Directory('lib/screens/transfer').listSync(recursive: true),
    ...Directory('lib/domain/payments').listSync(recursive: true),
    ...Directory('lib/domain/contacts').listSync(recursive: true),
    File('lib/data/repositories/demo_contact_repository.dart'),
    File('lib/design_system/components/fp_swipe_to_pay.dart'),
    File('lib/design_system/components/fp_processing_ring.dart'),
    File('lib/core/platform/fakes/fake_payment_gateway.dart'),
  ].whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  test('the payment feature files exist', () {
    expect(files.length, greaterThanOrEqualTo(14));
  });

  for (final file in files) {
    test('${file.path} never prints or logs', () {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('print(')), reason: file.path);
      expect(source, isNot(contains('debugPrint(')), reason: file.path);
      expect(source, isNot(contains('Logger.')), reason: file.path);
      expect(source, isNot(contains('developer.log(')), reason: file.path);
    });
  }

  test('no raw Color, Duration or Curve literals in the transfer screens', () {
    // The cubits under transfer/ and payment/ hold a ledger timeout, which
    // is not motion; the rule covers the screens and their widgets.
    final screens = Directory('lib/screens/transfer')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              !f.path.contains('/transfer/transfer/') &&
              !f.path.contains('/transfer/payment/'),
        );
    expect(screens.length, 7);
    for (final file in screens) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('Color(0x')), reason: file.path);
      expect(source, isNot(contains('Colors.')), reason: file.path);
      expect(
        source,
        isNot(matches(RegExp(r'Duration\(\s*(milli|micro)?seconds'))),
        reason: file.path,
      );
      expect(source, isNot(contains('Curves.')), reason: file.path);
    }
  });
}
