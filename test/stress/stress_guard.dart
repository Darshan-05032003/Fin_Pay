import 'package:flutter_test/flutter_test.dart';

/// True when the suite was started with `--dart-define=FINPAY_STRESS=true`.
const bool stressEnabled = bool.fromEnvironment('FINPAY_STRESS');

/// Call first thing in `main()` of every stress test file.
///
/// Returns `false` (after registering one skipped placeholder test, so the
/// file is never "empty") when the stress flag is off. Usage:
///
/// ```dart
/// @Tags(['stress'])
/// library;
///
/// void main() {
///   if (!stressGuard()) return;
///   ...
/// }
/// ```
bool stressGuard() {
  if (stressEnabled) return true;
  test(
    'stress suite',
    () {},
    skip: 'Run: flutter test --tags stress --dart-define=FINPAY_STRESS=true',
  );
  return false;
}
