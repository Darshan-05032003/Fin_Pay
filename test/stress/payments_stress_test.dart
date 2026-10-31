@Tags(['stress'])
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:fin_pay/domain/payments/payment_gateway.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/transfer/payment/payment_cubit.dart';
import 'package:fin_pay/screens/transfer/widgets/contact_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../widget/screens/screen_harness.dart';
import '../widget/screens/transfer_fixtures.dart';
import 'stress_guard.dart';

/// F5 load tests. Run with:
///
///   flutter test --tags stress --dart-define=FINPAY_STRESS=true \
///     --concurrency=1 test/stress/payments_stress_test.dart
///
/// Numbers are printed and recorded in docs/LOAD_TEST_REPORT.md.
void main() {
  if (!stressGuard()) return;

  String stats(List<int> micros) {
    final sorted = [...micros]..sort();
    final avg = sorted.reduce((a, b) => a + b) / sorted.length;
    final p90 = sorted[(sorted.length * 0.9).floor()];
    final p99 = sorted[(sorted.length * 0.99).floor()];
    final over = sorted.where((t) => t > 16000).length;
    return '${sorted.length} frames, avg ${(avg / 1000).toStringAsFixed(2)} '
        'ms, p90 ${(p90 / 1000).toStringAsFixed(2)} ms, '
        'p99 ${(p99 / 1000).toStringAsFixed(2)} ms, > 16 ms: $over';
  }

  int rssMb() => ProcessInfo.currentRss ~/ (1024 * 1024);

  final thumb = find.byKey(const ValueKey('fp-swipe-thumb'));

  testWidgets('1,000 rapid swipes, taps and multi-touch on the slider → '
      'exactly one ledger write', (tester) async {
    final h = ScreenHarness();
    final gateway = FakePaymentGateway(gated: true);
    final repos = TransferRepos(gateway: gateway);
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.transferReview, extra: fixtureDraft);
    await h.settle(tester);
    final sw = Stopwatch()..start();
    final a = await tester.startGesture(tester.getCenter(thumb));
    final b = await tester.startGesture(
      tester.getCenter(thumb) + const Offset(0, 6),
      pointer: 2,
    );
    await a.moveBy(const Offset(420, 0));
    await b.moveBy(const Offset(420, 0));
    await a.up();
    await b.up();
    for (var i = 0; i < 1000; i++) {
      if (i.isEven) {
        final g = await tester.startGesture(
          tester.getCenter(thumb),
          pointer: 10 + i,
        );
        await g.moveBy(const Offset(420, 0));
        await g.up();
      } else {
        await tester.tap(
          find.byKey(const ValueKey('review-swipe')),
          warnIfMissed: false,
        );
      }
      if (i % 100 == 0) await tester.pump();
    }
    sw.stop();
    await h.settle(tester);
    expect(gateway.authorizeCalls, hasLength(1));
    gateway.release();
    await h.settle(tester);
    expect(repos.ledgerCalls, hasLength(1));
    expect(h.location, AppRoutes.transferSuccess);
    debugPrint(
      'STRESS slider: 1,002 gestures in ${sw.elapsedMilliseconds} ms → '
      '${gateway.authorizeCalls.length} authorize, '
      '${repos.ledgerCalls.length} ledger write(s)',
    );
  });

  test('1,000 sequential payments through PaymentCubit + TransactionBloc '
      'on an in-memory ledger leave no listener behind', () async {
    sqfliteFfiInit();
    Logger.sink = (_) {};
    final haptics = FakeHapticService();
    await di.init(
      overrides: di.DiOverrides(
        haptics: haptics,
        biometrics: FakeBiometricAuthenticator(),
        motionSensor: FakeMotionSensor(),
        screenProtector: FakeScreenProtector(),
        secureStorage: FakeSecureStorage(),
        settingsRepository: InMemorySettingsRepository(),
        databaseFactory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
        clock: Clock.fixed(DateTime.utc(2026, 10, 31, 12)),
        paymentGateway: SimulatedPaymentGateway(latency: Duration.zero),
      ),
    );
    addTearDown(di.reset);
    final users = di.sl<IUserRepository>();
    await users.saveUser(
      User(
        id: 'u1',
        fullName: 'Aarav Mehta',
        email: 'user@finpay.com',
        balance: const Money.paise(100000000000),
        createdAt: DateTime.utc(2026),
      ),
    );
    final transactions = di.sl<TransactionBloc>();
    final gateway = di.sl<PaymentGateway>();
    final before = rssMb();
    final sw = Stopwatch()..start();
    var alreadyPaid = 0;
    var failures = 0;
    for (var i = 0; i < 1000; i++) {
      // Every tenth payment is a "flaky" bank: timeout, then a retry on
      // the same key that resolves as already paid.
      final flaky = i % 10 == 0;
      final cubit = PaymentCubit(
        draft: TransferDraft(
          recipientName: 'Payee $i',
          recipientAccount: flaky ? 'payee$i@flaky' : 'payee$i@okaxis',
          amount: Money.paise(100 + i),
          idempotencyKey: 'stress-$i',
        ),
        gateway: gateway,
        transactions: transactions,
        clock: di.sl(),
      );
      await cubit.pay();
      if (cubit.state.phase == PaymentPhase.failure) {
        await cubit.retry();
      }
      if (cubit.state.phase != PaymentPhase.success) failures++;
      if (cubit.receipt?.alreadyPaid ?? false) alreadyPaid++;
      await cubit.close();
    }
    sw.stop();
    final after = rssMb();
    final rows = await di.sl<ITransactionRepository>().getTransactions();
    final count = switch (rows) {
      Success(data: final list) => list.length,
      Failure() => -1,
    };
    final balance = switch (await users.getCurrentUser()) {
      Success(data: final u) => u?.balance,
      Failure() => null,
    };
    expect(failures, 0);
    expect(count, 1000);
    expect(alreadyPaid, 100);
    expect(transactions.hasEffectListeners, isFalse);
    // 1,000 payments of (100 + i) paise = 100,000 + 499,500.
    expect(balance, const Money.paise(100000000000 - 599500));
    debugPrint(
      'STRESS 1,000 payments (100 flaky retries): ${sw.elapsedMilliseconds} '
      'ms, rows $count, already paid $alreadyPaid, RSS $before → $after MB, '
      'effect listeners after: ${transactions.hasEffectListeners}',
    );
    await transactions.close();
  });

  testWidgets('10,000 keypad inputs: frame times and a consistent amount', (
    tester,
  ) async {
    final h = ScreenHarness();
    final repos = TransferRepos();
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.transfer);
    await h.settle(tester);
    final frames = <int>[];
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      final key = switch (i % 13) {
        10 => 'dot',
        11 => 'backspace',
        12 => 'backspace',
        final d => '$d',
      };
      await tester.tap(find.byKey(ValueKey('key-$key')), warnIfMissed: false);
      final frame = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      frame.stop();
      frames.add(frame.elapsedMicroseconds);
    }
    sw.stop();
    await h.settle(tester);
    expect(tester.takeException(), isNull);
    // 13-key cycle × 769 full cycles + 3 keys (0, 1, 2) → '12' after the
    // cycle leaves a 7-digit cap behind; whatever it is, it must be a
    // valid amount the odometer agrees with.
    expect(
      find.bySemanticsLabel(RegExp(r'Amount ₹[0-9,]+\.\d\d, long press')),
      findsOneWidget,
    );
    debugPrint(
      'STRESS keypad: 10,000 inputs in ${sw.elapsedMilliseconds} ms; '
      '${stats(frames)}',
    );
  });

  testWidgets('confetti burst on the success screen: frame times', (
    tester,
  ) async {
    final h = ScreenHarness();
    final repos = TransferRepos();
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.transferSuccess, extra: fixtureReceipt);
    // Let the check draw (400 ms) so the burst starts.
    await tester.pump(const Duration(milliseconds: 450));
    final frames = <int>[];
    for (var f = 0; f < 100; f++) {
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      frames.add(sw.elapsedMicroseconds);
    }
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    debugPrint('STRESS confetti + odometer: ${stats(frames)}');
  });

  testWidgets('50 contacts: staggered entrance frame times and search', (
    tester,
  ) async {
    final h = ScreenHarness();
    final repos = TransferRepos();
    final many = [
      for (var i = 0; i < 50; i++)
        Contact(id: 'c$i', name: 'Contact Number$i', vpa: 'contact$i@okaxis'),
    ];
    when(repos.contacts.getContacts).thenAnswer((_) async => Success(many));
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.transfer);
    await tester.pump();
    final frames = <int>[];
    for (var f = 0; f < 60; f++) {
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      frames.add(sw.elapsedMicroseconds);
    }
    expect(find.byType(ContactAvatar), findsWidgets);
    final search = Stopwatch()..start();
    await typeInto(tester, const ValueKey('transfer-search'), 'number4');
    await tester.pump();
    search.stop();
    expect(find.byType(ContactAvatar).evaluate().length, lessThanOrEqualTo(11));
    await h.settle(tester);
    expect(tester.binding.transientCallbackCount, 0);
    debugPrint(
      'STRESS 50 contacts entrance: ${stats(frames)}; search filter '
      '${search.elapsedMicroseconds} µs',
    );
  });
}
