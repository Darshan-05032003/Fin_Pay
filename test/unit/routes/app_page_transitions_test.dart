import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_page_transitions.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'auth steps use shared-axis X; splash, home and the rest fade through',
    () {
      for (final path in [
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.createAccount,
        AppRoutes.verification,
        AppRoutes.fingerprintSetup,
        AppRoutes.passwordReset,
      ]) {
        expect(
          AppPageTransitions.kindFor(path),
          FpTransitionKind.sharedAxisX,
          reason: path,
        );
      }
      expect(
        AppPageTransitions.kindFor(AppRoutes.welcome),
        FpTransitionKind.fadeThrough,
      );
      expect(
        AppPageTransitions.kindFor(AppRoutes.home),
        FpTransitionKind.fadeThrough,
      );
      expect(
        AppPageTransitions.kindFor('/unknown'),
        AppPageTransitions.defaultKind,
      );
    },
  );

  test('the design-system builder is the default', () {
    expect(AppPageTransitions.builder, AppPageTransitions.fp);
  });
}
