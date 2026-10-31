@Tags(['stress'])
library;

import 'dart:io';

import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_state.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/core/settings/settings_repository.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/home/widgets/transaction_row.dart';
import 'package:fin_pay/screens/transactions/transactions_cubit.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../widget/screens/insights_activity_fixtures.dart';
import '../widget/screens/screen_harness.dart';
import 'stress_guard.dart';

/// F6 load tests. Run with:
///
///   flutter test --tags stress --dart-define=FINPAY_STRESS=true \
///     --concurrency=1 test/stress/insights_activity_stress_test.dart
///
/// Numbers are printed and recorded in docs/LOAD_TEST_REPORT.md.
void main() {
  if (!stressGuard()) return;

  String stats(List<int> micros) {
    final sorted = [...micros]..sort();
    final avg = sorted.reduce((a, b) => a + b) / sorted.length;
    final p90 = sorted[(sorted.length * 0.9).floor()];
    final p99 =
        sorted[(sorted.length * 0.99).floor().clamp(0, sorted.length - 1)];
    final over = sorted.where((t) => t > 16000).length;
    return '${sorted.length} frames, avg ${(avg / 1000).toStringAsFixed(2)} '
        'ms, p90 ${(p90 / 1000).toStringAsFixed(2)} ms, '
        'p99 ${(p99 / 1000).toStringAsFixed(2)} ms, > 16 ms: $over';
  }

  int rssMb() => ProcessInfo.currentRss ~/ (1024 * 1024);

  Finder scrollable() => find
      .descendant(
        of: find.byKey(const ValueKey('transactions-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;

  /// Seeds [count] rows into the real in-memory ledger in batches.
  Future<void> seedLedger(WidgetTester tester, int count) async {
    final repo = di.sl<ITransactionRepository>();
    final sw = Stopwatch()..start();
    await tester.runAsync(() async {
      const batch = 5000;
      for (var from = 0; from < count; from += batch) {
        final rows = fixtureLedger(batch.clamp(0, count - from), rowsPerDay: 40)
            .indexed
            .map((e) {
              final (i, t) = e;
              final n = from + i;
              return t.copyWith(
                id: 'tx${n.toString().padLeft(7, '0')}',
                idempotencyKey: 'key-$n',
                date: insightsNow.subtract(Duration(minutes: n)),
              );
            })
            .toList();
        final result = await repo.addTransactions(rows);
        expect(result.isSuccess, isTrue);
      }
    });
    debugPrint('[stress] seeded $count rows in ${sw.elapsedMilliseconds} ms');
  }

  for (final count in [10000, 100000]) {
    testWidgets('$count-row ledger: first page, 50 pages of scrolling, '
        'search', (tester) async {
      final h = ScreenHarness();
      await h.init(tester, signedIn: true);
      await seedLedger(tester, count);
      final repo = di.sl<ITransactionRepository>();

      // First page through the cubit (what the screen does on open).
      final cubit = TransactionsCubit(repository: repo);
      final first = Stopwatch()..start();
      await tester.runAsync(cubit.load);
      first.stop();
      expect(cubit.state.items.length, 50);
      expect(cubit.state.hasMore, isTrue);
      debugPrint(
        '[stress] $count rows: first page in ${first.elapsedMilliseconds} ms',
      );

      // Deep pages: offset paging cost near the end of the ledger.
      final deep = Stopwatch()..start();
      final deepPage = await tester.runAsync(
        () => repo.getTransactions(limit: 50, offset: count - 50),
      );
      deep.stop();
      expect(deepPage!.dataOrNull!.length, 50);
      debugPrint(
        '[stress] $count rows: page at offset ${count - 50} in '
        '${deep.elapsedMilliseconds} ms',
      );
      await cubit.close();

      // The real screen: scroll 50 pages worth, frame times.
      await h.pump(tester, AppRoutes.transactions);
      await h.flush(tester, rounds: 5);
      await h.settle(tester);
      expect(find.byType(TransactionRow), findsWidgets);
      final frames = <int>[];
      var loads = 0;
      final scroll = Stopwatch()..start();
      for (var page = 0; page < 50; page++) {
        for (var f = 0; f < 6; f++) {
          await tester.drag(scrollable(), const Offset(0, -600));
          final sw = Stopwatch()..start();
          await tester.pump(const Duration(milliseconds: 16));
          sw.stop();
          frames.add(sw.elapsedMicroseconds);
        }
        // Let the next page come back from the ffi worker.
        await h.flush(tester, rounds: 2);
        loads++;
      }
      scroll.stop();
      final state = BlocProvider.of<TransactionsCubit>(
        tester.element(find.byKey(const ValueKey('transactions-scroll'))),
      ).state;
      debugPrint(
        '[stress] $count rows: 50 pages scrolled in '
        '${scroll.elapsedMilliseconds} ms, ${state.items.length} rows loaded '
        '($loads page waits): ${stats(frames)}; RSS ${rssMb()} MB',
      );
      expect(state.items.length, greaterThanOrEqualTo(1000));
      expect(state.items.map((t) => t.id).toSet().length, state.items.length);

      // Search over the whole ledger (parameterised LIKE, capped at 50).
      for (final q in ['Priya', 'Coffee 9', 'zzz', "' OR 1=1 --"]) {
        final sw = Stopwatch()..start();
        final result = await tester.runAsync(() => repo.searchTransactions(q));
        sw.stop();
        final rows = result!.dataOrNull!;
        debugPrint(
          '[stress] $count rows: search "$q" → '
          '${rows.length} rows in ${sw.elapsedMilliseconds} ms',
        );
      }
      await h.flush(tester, rounds: 3);
    });
  }

  test(
    '1,000 rapid toggle flips: consistent state and one write each',
    () async {
      final repo = InMemorySettingsRepository();
      final cubit = SettingsCubit(repo);
      await cubit.load();
      final sw = Stopwatch()..start();
      final flips = <Future<void>>[];
      for (var i = 0; i < 1000; i++) {
        flips
          ..add(cubit.setHapticsEnabled(enabled: i.isEven))
          ..add(cubit.toggleHideBalance());
      }
      await Future.wait(flips);
      sw.stop();
      debugPrint(
        '[stress] 2,000 flips in ${sw.elapsedMilliseconds} ms, '
        '${repo.saves} writes',
      );
      // Haptics ended on the last value (i = 999 → false); hide balance was
      // toggled 1,000 times → back to false.
      expect(cubit.state.hapticsEnabled, isFalse);
      expect(cubit.state.hideBalance, isFalse);
      expect(repo.settings, cubit.state.settings);
      expect(repo.settings, const AppSettings(hapticsEnabled: false));
      // The very first flip set haptics to its current value (true), which
      // the cubit treats as a no-op: 1,999 real changes → 1,999 writes.
      expect(repo.saves, 1999);
      await cubit.close();
    },
  );

  testWidgets('1,000 swipe-dismiss + undo cycles leave no tickers, toasts '
      'or listeners behind', (tester) async {
    final h = ScreenHarness();
    final repos = InsightsRepos();
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.notifications);
    await h.settle(tester);
    final bloc = BlocProvider.of<NotificationBloc>(
      tester.element(find.byKey(const ValueKey('notifications-scroll'))),
    );
    final row = find.byKey(const ValueKey('notification-n0'));
    final rssBefore = rssMb();
    final sw = Stopwatch()..start();
    var undone = 0;
    for (var i = 0; i < 1000; i++) {
      await tester.dragFrom(tester.getCenter(row), const Offset(-320, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(row, findsNothing, reason: 'cycle $i');
      // The toast slides in after the row collapsed; let it land.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('fp-toast-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      undone++;
      expect(row, findsOneWidget, reason: 'cycle $i');
    }
    sw.stop();
    // Finite pulses chain pulse → pulse across frames; several frames let
    // the last one end.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    final state = bloc.state as NotificationContent;
    debugPrint(
      '[stress] 1,000 dismiss+undo cycles in ${sw.elapsedMilliseconds} ms '
      '($undone undos): ${state.notifications.length} rows, toast open: '
      '${FpToast.current != null}, transient callbacks: '
      '${tester.binding.transientCallbackCount}, RSS $rssBefore → '
      '${rssMb()} MB',
    );
    expect(state.notifications.length, 8);
    expect(state.notifications.map((n) => n.id).toSet().length, 8);
    expect(FpToast.current, isNull);
    expect(tester.binding.transientCallbackCount, 0);
    verify(() => repos.notes.deleteNotification('n0')).called(1000);
    verify(() => repos.notes.addNotification(any())).called(1000);
  });

  testWidgets('statistics with 365 daily points: entrance and period '
      'switches frame times', (tester) async {
    final h = ScreenHarness();
    final repos = InsightsRepos(ledgerRows: 0);
    final year = [
      for (var i = 0; i < 365 * 4; i++)
        Transaction(
          id: 'y$i',
          title: 'Merchant ${i % 23}',
          amount: Money.paise(i % 4 == 0 ? 120000 : -(1000 + i % 777)),
          date: insightsNow.subtract(Duration(hours: 6 * i)),
          type: i % 4 == 0
              ? TransactionType.receiveMoney
              : TransactionType.payment,
          icon: 'c${i % 9}',
        ),
    ];
    when(() => repos.txns.getTransactionsBetween(any(), any())).thenAnswer((
      inv,
    ) async {
      final from = inv.positionalArguments[0] as DateTime;
      final to = inv.positionalArguments[1] as DateTime;
      return Success(
        year
            .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
            .toList(),
      );
    });
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.statistics);
    await tester.pump();
    await tester.tap(find.text('Year'));
    await tester.pump();
    final frames = <int>[];
    for (var f = 0; f < 60; f++) {
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      frames.add(sw.elapsedMicroseconds);
    }
    final line = tester.widget<LineChart>(find.byType(LineChart));
    expect(line.data.lineBarsData.single.spots.length, 365);
    debugPrint('[stress] year chart entrance (365 points): ${stats(frames)}');
    final switches = <int>[];
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text(i.isEven ? 'Week' : 'Year'));
      for (var f = 0; f < 30; f++) {
        final sw = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 16));
        sw.stop();
        switches.add(sw.elapsedMicroseconds);
      }
    }
    debugPrint(
      '[stress] 10 period switches (30 frames each): ${stats(switches)}',
    );
    await h.settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('500 notifications: staggered entrance and mark all read', (
    tester,
  ) async {
    final h = ScreenHarness();
    final repos = InsightsRepos();
    final many = [
      for (var i = 0; i < 500; i++)
        NotificationItem(
          id: 'm$i',
          title: 'Notification $i',
          message: 'Message $i for the stress list.',
          time: insightsNow.subtract(Duration(minutes: i)),
          type: NotificationType.values[i % NotificationType.values.length],
          isRead: i.isOdd,
        ),
    ];
    repos.notifications
      ..clear()
      ..addAll(many);
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.notifications);
    await tester.pump();
    final frames = <int>[];
    for (var f = 0; f < 60; f++) {
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      frames.add(sw.elapsedMicroseconds);
    }
    debugPrint('[stress] 500 notifications entrance: ${stats(frames)}');
    final scroll = <int>[];
    for (var i = 0; i < 40; i++) {
      await tester.drag(
        find.byKey(const ValueKey('notifications-scroll')),
        const Offset(0, -700),
      );
      final sw = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      scroll.add(sw.elapsedMicroseconds);
    }
    debugPrint(
      '[stress] 500 notifications, 40 scroll frames: ${stats(scroll)}',
    );
    final markAll = Stopwatch()..start();
    await tester.tap(find.byKey(const ValueKey('notifications-mark-all')));
    await tester.pump();
    await h.settle(tester);
    markAll.stop();
    final captured = verify(() => repos.notes.markRead(captureAny())).captured;
    final ids = captured.single as List<String>;
    debugPrint(
      '[stress] mark all read: ${ids.length} ids in one '
      'write, ${markAll.elapsedMilliseconds} ms',
    );
    expect(ids.length, 250);
    expect(find.byKey(const ValueKey('notifications-mark-all')), findsNothing);
  });
}
