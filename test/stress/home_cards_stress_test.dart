@Tags(['stress'])
library;

import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/motion_sensor.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/home/widgets/transaction_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../widget/screens/home_cards_fixtures.dart';
import '../widget/screens/screen_harness.dart';
import 'stress_guard.dart';

/// F4 load tests. Run with:
///
///   flutter test --tags stress --dart-define=FINPAY_STRESS=true \
///     --concurrency=1 test/stress/home_cards_stress_test.dart
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

  List<PaymentCard> manyCards(int n) => [
    for (var i = 0; i < n; i++)
      fixtureCards[i % fixtureCards.length].copyWith(
        id: 'card-$i',
        cardNumber:
            '4111 1111 11${(1000 + i).toString().substring(1)} '
            '${(1000 + i * 7 % 10000).toString().padLeft(4, '0')}',
      ),
  ];

  testWidgets('50 cards: 300 frames of 60 Hz tilt and 20 flips leave no '
      'ticker behind', (tester) async {
    final h = ScreenHarness();
    final repos = HomeCardsRepos();
    final cards = manyCards(50);
    when(repos.cards.getCards).thenAnswer((_) async => Success(cards));
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.cards);
    await h.settle(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('tap to fan out')));
    await tester.pump();
    await h.settle(tester);
    expect(h.sensor.listeners, 1);
    final frames = <int>[];
    for (var f = 0; f < 300; f++) {
      h.sensor.emit(Tilt((f % 60) / 30 - 1, ((f * 7) % 60) / 30 - 1));
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      frames.add(sw.elapsedMicroseconds);
    }
    final flipFrames = <int>[];
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byKey(const ValueKey('focused-card-card-0')));
      for (var f = 0; f < 30; f++) {
        h.sensor.emit(Tilt(f / 30, 0));
        final sw = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 16));
        sw.stop();
        flipFrames.add(sw.elapsedMicroseconds);
      }
    }
    debugPrint('[stress] 50-card stack, tilt at 60 Hz: ${stats(frames)}');
    debugPrint('[stress] 20 flips under tilt: ${stats(flipFrames)}');
    expect(tester.takeException(), isNull);
    // Swipe across ten cards while tilting.
    final swipeFrames = <int>[];
    for (var i = 0; i < 10; i++) {
      await tester.drag(
        find.byKey(const ValueKey('card-carousel')),
        const Offset(-320, 0),
      );
      for (var f = 0; f < 20; f++) {
        h.sensor.emit(Tilt(f / 20, -f / 20));
        final sw = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 16));
        sw.stop();
        swipeFrames.add(sw.elapsedMicroseconds);
      }
    }
    debugPrint('[stress] 10 swipes under tilt: ${stats(swipeFrames)}');
    await h.dispose(tester);
    final tickers = SchedulerBinding.instance.transientCallbackCount;
    debugPrint(
      '[stress] tickers after dispose: $tickers, sensor listeners: '
      '${h.sensor.listeners}',
    );
    expect(tickers, 0);
    expect(h.sensor.listeners, 0);
  });

  testWidgets('home with 10,000 transactions in the database shows five', (
    tester,
  ) async {
    final h = ScreenHarness();
    await h.init(tester, signedIn: true);
    final ds = di.sl<LocalDataSource>();
    final base = DateTime.utc(2026, 10, 31, 12);
    final seedSw = Stopwatch()..start();
    await tester.runAsync(() async {
      await ds.saveUser(harnessUser);
      for (var start = 0; start < 10000; start += 2500) {
        await ds.saveTransactions([
          for (var i = start; i < start + 2500; i++)
            Transaction(
              id: 'tx-$i',
              title: 'Merchant ${i % 997} order $i',
              amount: Money.paise(i.isEven ? -(i % 50000 + 1) : i % 9000 + 1),
              date: base.subtract(Duration(minutes: i)),
              type: i.isEven
                  ? TransactionType.payment
                  : TransactionType.receiveMoney,
              icon: 'M',
            ),
        ]);
      }
    });
    seedSw.stop();
    final loadSw = Stopwatch()..start();
    await h.pump(tester, AppRoutes.home);
    var rounds = 0;
    while (find.byKey(const ValueKey('home-balance')).evaluate().isEmpty &&
        rounds < 100) {
      await h.flush(tester, rounds: 1);
      rounds++;
    }
    loadSw.stop();
    await h.settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-see-all')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('home-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await h.flush(tester, rounds: 5);
    await h.settle(tester);
    final rows = find.byType(TransactionRow).evaluate().length;
    final rss = ProcessInfo.currentRss ~/ (1024 * 1024);
    debugPrint(
      '[stress] 10k transactions: seed ${seedSw.elapsedMilliseconds} ms, '
      'home ready in ${loadSw.elapsedMilliseconds} ms, rows on screen: '
      '$rows, RSS $rss MB',
    );
    expect(rows, 5);
    expect(find.text('Merchant 0 order 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('1,000 rapid taps on hide balance: consistent state, one write '
      'per change', (tester) async {
    final h = ScreenHarness();
    final repos = HomeCardsRepos();
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.home);
    await h.settle(tester);
    await tester.pump(const Duration(seconds: 2));
    final eye = tester.getCenter(
      find.byKey(const ValueKey('home-hide-balance')),
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      await tester.tapAt(eye);
    }
    sw.stop();
    await tester.pump();
    await h.settle(tester);
    final hidden = h.settings.state.hideBalance;
    debugPrint(
      '[stress] 1000 hide-balance taps in ${sw.elapsedMilliseconds} ms: '
      'hidden=$hidden, persisted=${h.settingsRepo.settings.hideBalance}, '
      'writes=${h.settingsRepo.saves}',
    );
    expect(hidden, isFalse, reason: 'an even number of toggles');
    expect(h.settingsRepo.settings.hideBalance, hidden);
    expect(h.settingsRepo.saves, 1000);
    expect(find.text(FpAmountText.masked), findsNothing);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('1,000 submissions of the same card store exactly one', (
    tester,
  ) async {
    final h = ScreenHarness();
    final repos = HomeCardsRepos();
    final stored = <PaymentCard>[];
    final gate = Completer<Result<void>>();
    when(() => repos.cards.addCard(any())).thenAnswer((invocation) {
      stored.add(invocation.positionalArguments.first as PaymentCard);
      return gate.future;
    });
    when(
      repos.cards.getCards,
    ).thenAnswer((_) async => Success([...stored, ...fixtureCards]));
    await h.init(
      tester,
      signedIn: true,
      cardRepository: repos.cards,
      transactionRepository: repos.txns,
      userRepository: repos.users,
      clock: Clock.fixed(DateTime(2026, 10, 31, 12)),
    );
    await h.pump(tester, AppRoutes.addCard);
    await h.settle(tester);
    await typeInto(
      tester,
      const ValueKey('add-card-number'),
      '4111 1111 1111 1111',
    );
    await typeInto(tester, const ValueKey('add-card-name'), 'Aarav Mehta');
    await typeInto(tester, const ValueKey('add-card-expiry'), '12/30');
    await typeInto(tester, const ValueKey('add-card-cvv'), '321');
    final button = tester.getCenter(
      find.byKey(const ValueKey('add-card-submit')),
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      await tester.tapAt(button);
    }
    sw.stop();
    await tester.pump();
    gate.complete(const Success(null));
    await tester.pump();
    await h.settle(tester);
    // The screen has left; the form cannot be submitted again.
    debugPrint(
      '[stress] 1000 add-card taps in ${sw.elapsedMilliseconds} ms: '
      'stored=${stored.length}, location=${h.location}',
    );
    expect(stored, hasLength(1));
    expect(h.location, isNot(AppRoutes.addCard));
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('odometer counts up to ₹99,99,99,999.99 on home', (tester) async {
    final h = ScreenHarness();
    final repos = HomeCardsRepos();
    when(repos.users.getCurrentUser).thenAnswer(
      (_) async =>
          Success(harnessUser.copyWith(balance: const Money.paise(9999999999))),
    );
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.home, textScale: 1.3);
    await tester.pump();
    final frames = <int>[];
    for (var f = 0; f < 60; f++) {
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      frames.add(sw.elapsedMicroseconds);
    }
    debugPrint('[stress] odometer to max at 1.3x: ${stats(frames)}');
    expect(
      tester.getSemantics(find.byKey(const ValueKey('home-balance'))).label,
      'Available balance ₹9,99,99,999.99',
    );
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });
}
