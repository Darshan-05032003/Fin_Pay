@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/payments/payment_gateway.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget/screens/screen_harness.dart';
import '../../widget/screens/transfer_fixtures.dart';

/// Transfer, review (idle, dragging, locked), failure and success in their
/// main states at 1.0× and 1.3×. Baselines live in
/// `goldens/transfer_<state>_<scale>.png`; regenerate with
/// `flutter test --update-goldens test/golden/screens/transfer_golden_test.dart`
/// only when a change is intended.
void main() {
  late ScreenHarness h;
  late TransferRepos repos;
  final fixedClock = Clock.fixed(DateTime(2026, 10, 31, 9, 30));

  setUp(() {
    h = ScreenHarness();
    repos = TransferRepos();
  });

  Future<void> boot(WidgetTester tester, {FakePaymentGateway? gateway}) {
    if (gateway != null) repos = TransferRepos(gateway: gateway);
    return h.init(
      tester,
      signedIn: true,
      cardRepository: repos.cards,
      transactionRepository: repos.txns,
      userRepository: repos.users,
      contactRepository: repos.contacts,
      paymentGateway: repos.gateway,
      clock: fixedClock,
    );
  }

  Future<void> snap(WidgetTester tester, String name, double scale) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final s = scale.toStringAsFixed(1).replaceAll('.', '_');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/transfer_${name}_$s.png'),
    );
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey('key-$key')));
    await tester.pump();
  }

  final thumb = find.byKey(const ValueKey('fp-swipe-thumb'));

  for (final scale in [1.0, 1.3]) {
    group('${scale}x', () {
      testWidgets('transfer empty, typed and error', (tester) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.transfer, textScale: scale);
        await snap(tester, 'empty', scale);
        await tester.tap(find.byKey(const ValueKey('contact-c-priya')));
        await tester.pump();
        for (final k in ['1', '2', '5', '0']) {
          await tapKey(tester, k);
        }
        await typeInto(tester, const ValueKey('transfer-note'), 'Chai');
        await snap(tester, 'typed', scale);
        await tester.longPress(find.byKey(const ValueKey('key-backspace')));
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          await tapKey(tester, '9');
        }
        await snap(tester, 'amount_error', scale);
      });

      testWidgets('transfer load error', (tester) async {
        await boot(tester);
        when(
          repos.contacts.getContacts,
        ).thenAnswer((_) async => const Failure('No address book'));
        await h.pump(tester, AppRoutes.transfer, textScale: scale);
        await snap(tester, 'load_error', scale);
      });

      testWidgets('review idle, dragging and locked', (tester) async {
        await boot(tester, gateway: FakePaymentGateway(gated: true));
        await h.pump(
          tester,
          AppRoutes.transferReview,
          extra: fixtureDraft,
          textScale: scale,
        );
        await snap(tester, 'review_idle', scale);
        final gesture = await tester.startGesture(tester.getCenter(thumb));
        await gesture.moveBy(const Offset(120, 0));
        await tester.pump();
        await snap(tester, 'review_dragging', scale);
        await gesture.moveBy(const Offset(400, 0));
        await gesture.up();
        await tester.pump();
        await snap(tester, 'review_locked', scale);
        repos.gateway.release();
        await h.settle(tester);
      });

      testWidgets('failure', (tester) async {
        await boot(
          tester,
          gateway: FakePaymentGateway(
            authorizeResults: const [GatewayDeclined('Your bank said no.')],
          ),
        );
        await h.pump(
          tester,
          AppRoutes.transferReview,
          extra: fixtureDraft,
          textScale: scale,
        );
        await h.settle(tester);
        await tester.drag(thumb, const Offset(420, 0));
        await tester.pump();
        await snap(tester, 'failure', scale);
      });

      testWidgets('success', (tester) async {
        await boot(tester);
        await h.pump(
          tester,
          AppRoutes.transferSuccess,
          extra: fixtureReceipt,
          textScale: scale,
        );
        await snap(tester, 'success', scale);
      });
    });
  }
}
