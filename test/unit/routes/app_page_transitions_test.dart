import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_page_transitions.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every route has an explicit transition kind (F7): shared-axis X for the
/// steps of a flow, Y for the add-card sheet, Z for drill-in lists and
/// fade-through for root switches and results. Nothing relies on the
/// default silently.
void main() {
  test('every known route has an explicit transition kind', () {
    for (final path in AppRoutes.all) {
      expect(
        AppPageTransitions.kinds.containsKey(path),
        isTrue,
        reason: '$path falls back to the default kind',
      );
    }
    expect(AppPageTransitions.kinds.length, AppRoutes.all.length);
  });

  test('steps of a flow use shared-axis X', () {
    for (final path in [
      AppRoutes.onboarding,
      AppRoutes.login,
      AppRoutes.createAccount,
      AppRoutes.verification,
      AppRoutes.fingerprintSetup,
      AppRoutes.passwordReset,
      AppRoutes.transfer,
      AppRoutes.transferReview,
    ]) {
      expect(
        AppPageTransitions.kindFor(path),
        FpTransitionKind.sharedAxisX,
        reason: path,
      );
    }
  });

  test('root switches and results fade through', () {
    for (final path in [
      AppRoutes.welcome,
      AppRoutes.home,
      AppRoutes.statistics,
      AppRoutes.cards,
      AppRoutes.profile,
      AppRoutes.transferSuccess,
      AppRoutes.cardDetails,
      AppRoutes.gallery,
    ]) {
      expect(
        AppPageTransitions.kindFor(path),
        FpTransitionKind.fadeThrough,
        reason: path,
      );
    }
  });

  test('the add-card form rises like a sheet (shared-axis Y)', () {
    expect(
      AppPageTransitions.kindFor(AppRoutes.addCard),
      FpTransitionKind.sharedAxisY,
    );
  });

  test('drill-in lists zoom in (shared-axis Z)', () {
    expect(
      AppPageTransitions.kindFor(AppRoutes.transactions),
      FpTransitionKind.sharedAxisZ,
    );
    expect(
      AppPageTransitions.kindFor(AppRoutes.notifications),
      FpTransitionKind.sharedAxisZ,
    );
  });

  test('a concrete card-details path matches the pattern entry', () {
    expect(
      AppPageTransitions.kindFor(AppRoutes.cardDetailsFor('card 1/x')),
      FpTransitionKind.fadeThrough,
    );
    expect(
      AppPageTransitions.kindFor('/unknown'),
      AppPageTransitions.defaultKind,
    );
  });

  test('the design-system builder is the default and the plain fade uses '
      'the motion tokens', () {
    expect(AppPageTransitions.builder, AppPageTransitions.fp);
    expect(AppPageTransitions.fadeDuration, FpMotion.standard);
  });
}
