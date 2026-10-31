import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/home/widgets/transaction_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'insights_activity_fixtures.dart';
import 'screen_harness.dart';

// `type: null` is deliberate in the verifies (see transactions_cubit_test).
// ignore_for_file: avoid_redundant_argument_values

void main() {
  late ScreenHarness h;
  late InsightsRepos repos;

  setUp(() => h = ScreenHarness());

  Future<void> open(
    WidgetTester tester, {
    int rows = 40,
    double scale = 1,
    bool rm = false,
    AppSettings settings = AppSettings.defaults,
    bool settle = true,
  }) async {
    repos = InsightsRepos(ledgerRows: rows);
    await repos.init(h, tester: tester, initialSettings: settings);
    await h.pump(
      tester,
      AppRoutes.transactions,
      textScale: scale,
      reduceMotion: rm,
    );
    if (settle) await h.settle(tester);
  }

  Finder scrollable() => find
      .descendant(
        of: find.byKey(const ValueKey('transactions-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;

  Finder row(String id) => find.byKey(ValueKey('tx-$id'));

  Offset rowCenter(WidgetTester tester, String id) => tester.getCenter(row(id));

  Future<void> swipe(WidgetTester tester, String id, double dx) async {
    await tester.dragFrom(rowCenter(tester, id), Offset(dx, 0));
    await tester.pump();
    await h.settle(tester);
  }

  /// The action tile of the one row whose tray is open (every row has a
  /// tray; only the open one is hittable).
  Finder openAction(WidgetTester tester, String label) => find
      .byWidgetPredicate(
        (w) => w.key == ValueKey('fp-swipe-action-$label'),
        skipOffstage: false,
      )
      .hitTestable();

  Finder deleteAction(WidgetTester tester) => openAction(tester, 'Delete');

  Finder detailsAction(WidgetTester tester) => openAction(tester, 'Details');

  double foregroundDx(WidgetTester tester, String id) =>
      tester
          .getTopLeft(
            find.descendant(of: row(id), matching: find.byType(TransactionRow)),
          )
          .dx -
      tester.getTopLeft(row(id)).dx;

  group('states', () {
    testWidgets('loading: skeleton rows while the first page is pending', (
      tester,
    ) async {
      repos = InsightsRepos();
      final gate = Completer<Result<List<Transaction>>>();
      when(
        () => repos.txns.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) => gate.future);
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.transactions);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('transactions-skeleton')),
        findsOneWidget,
      );
      expect(find.byType(FpSkeletonRow), findsWidgets);
      expect(h.protector.enabled, isTrue, reason: 'FLAG_SECURE');
      gate.complete(Success(repos.ledger.take(5).toList()));
      await tester.pump();
      await h.settle(tester);
      expect(find.byKey(const ValueKey('transactions-skeleton')), findsNothing);
      expect(find.byType(TransactionRow), findsNWidgets(5));
    });

    testWidgets('empty: "No transactions yet" with a finite pulse', (
      tester,
    ) async {
      await open(tester, rows: 0);
      expect(find.text('No transactions yet'), findsOneWidget);
      final pulse = tester.widget<FpPulse>(
        find.byKey(const ValueKey('transactions-empty')),
      );
      expect(pulse.pulses, isNotNull);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('error: message and retry reloads', (tester) async {
      repos = InsightsRepos();
      var calls = 0;
      when(
        () => repos.txns.getTransactions(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Failure('Storage unavailable')
            : Success(repos.ledger.take(3).toList());
      });
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.transactions);
      await h.settle(tester);
      expect(find.text('Could not load transactions'), findsOneWidget);
      expect(find.text('Storage unavailable'), findsOneWidget);
      await tapButton(tester, 'Retry');
      await h.settle(tester);
      expect(find.byType(TransactionRow), findsNWidgets(3));
    });

    testWidgets('content: grouped by day with sticky headers, amounts '
        'signed and FLAG_SECURE on', (tester) async {
      await open(tester);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('−₹150.00'), findsWidgets);
      expect(find.textContaining('+₹'), findsWidgets);
      expect(h.protector.enabled, isTrue);
      final listTop = tester.getTopLeft(scrollable()).dy;
      final today = find.byKey(const ValueKey('day-Today'));
      expect(tester.getTopLeft(today).dy, listTop);
      // Scroll inside the first group: its header stays pinned at the top.
      await tester.drag(scrollable(), const Offset(0, -200));
      await tester.pump();
      expect(tester.getTopLeft(today).dy, listTop, reason: 'pinned');
      expect(find.text('TODAY'), findsOneWidget);
      // Scroll past the group: the next day's header takes its place.
      await tester.drag(scrollable(), const Offset(0, -500));
      await tester.pump();
      expect(find.byKey(const ValueKey('day-Today')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('day-Yesterday'))).dy,
        listTop,
      );
    });

    testWidgets('hide balance masks every amount', (tester) async {
      await open(tester, settings: const AppSettings(hideBalance: true));
      expect(find.text('−₹150.00'), findsNothing);
      expect(find.text(FpAmountText.masked), findsWidgets);
    });
  });

  group('paging', () {
    testWidgets('scrolling near the end loads the next page once', (
      tester,
    ) async {
      await open(tester, rows: 120);
      Future<void> scrollToEnd() async {
        for (var i = 0; i < 12; i++) {
          await tester.drag(scrollable(), const Offset(0, -800));
          await tester.pump();
        }
        await h.settle(tester);
      }

      await scrollToEnd();
      verify(
        () => repos.txns.getTransactions(limit: 50, offset: 50, type: null),
      ).called(1);
      // Keep scrolling: the third page comes and the loader disappears.
      await scrollToEnd();
      verify(
        () => repos.txns.getTransactions(limit: 50, offset: 100, type: null),
      ).called(1);
      await scrollToEnd();
      expect(
        find.byKey(const ValueKey('transactions-load-more')),
        findsNothing,
      );
      verifyNever(
        () => repos.txns.getTransactions(limit: 50, offset: 120, type: null),
      );
    });

    testWidgets('pull to refresh reloads the first page', (tester) async {
      await open(tester);
      await tester.drag(scrollable(), const Offset(0, 300));
      await tester.pump();
      await h.settle(tester);
      verify(
        () => repos.txns.getTransactions(limit: 50, offset: 0, type: null),
      ).called(2);
      expect(h.haptics.calls, contains(HapticType.medium));
    });
  });

  group('search and filters', () {
    testWidgets('search is debounced and filters the list', (tester) async {
      await open(tester);
      await typeInto(tester, const ValueKey('transactions-search'), 'cof');
      await tester.pump(const Duration(milliseconds: 100));
      await typeInto(tester, const ValueKey('transactions-search'), 'coffee');
      await tester.pump(const Duration(milliseconds: 100));
      verifyNever(
        () => repos.txns.searchTransactions(any(), type: any(named: 'type')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await h.settle(tester);
      verify(
        () => repos.txns.searchTransactions('coffee', type: null),
      ).called(1);
      expect(find.text('Coffee'), findsWidgets);
      expect(find.text('Grocery run'), findsNothing);
      expect(
        find.byKey(const ValueKey('transactions-load-more')),
        findsNothing,
      );
      await typeInto(tester, const ValueKey('transactions-search'), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await h.settle(tester);
      expect(find.text('No matches'), findsOneWidget);
    });

    testWidgets('hostile search strings are harmless', (tester) async {
      await open(tester);
      for (final q in [
        "' OR 1=1 --",
        '\u202Ecoffee',
        '🙂' * 50,
        'x' * 400,
        'عربى',
      ]) {
        await typeInto(tester, const ValueKey('transactions-search'), q);
        await tester.pump(const Duration(milliseconds: 400));
        await h.settle(tester);
        expect(tester.takeException(), isNull, reason: q);
      }
      final queries = verify(
        () => repos.txns.searchTransactions(captureAny(), type: null),
      ).captured.cast<String>();
      expect(queries.every((q) => q.length <= 200), isTrue);
    });

    testWidgets('filter chips reload with the chip type and play a tick', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('filter-sent')));
      await tester.pump();
      await h.settle(tester);
      verify(
        () => repos.txns.getTransactions(
          limit: 50,
          offset: 0,
          type: TransactionType.sendMoney,
        ),
      ).called(1);
      expect(find.text('Sent to Priya'), findsWidgets);
      expect(find.text('Coffee'), findsNothing);
      expect(h.haptics.calls, contains(HapticType.selection));
      final chip = tester.widget<FpChip>(
        find.byKey(const ValueKey('filter-sent')),
      );
      expect(chip.selected, isTrue);
      await tester.tap(find.byKey(const ValueKey('filter-card')));
      await tester.pump();
      await h.settle(tester);
      expect(find.text('Wallet top-up'), findsWidgets);
    });
  });

  group('swipe actions', () {
    testWidgets('below the threshold the row snaps back; above it the '
        'actions appear', (tester) async {
      await open(tester);
      await swipe(tester, 'tx000000', -40);
      expect(foregroundDx(tester, 'tx000000'), closeTo(0, 0.5));
      await swipe(tester, 'tx000000', -120);
      expect(foregroundDx(tester, 'tx000000'), closeTo(-144, 0.5));
      expect(h.haptics.calls, contains(HapticType.selection));
    });

    testWidgets('delete removes the row, undo restores it in place; the '
        'home bloc is told both times', (tester) async {
      await open(tester);
      final before = tester.getTopLeft(row('tx000001')).dy;
      await swipe(tester, 'tx000001', -120);
      await tester.tap(deleteAction(tester));
      await tester.pump();
      await h.settle(tester);
      expect(row('tx000001'), findsNothing);
      expect(find.text('Transaction deleted'), findsOneWidget);
      verify(() => repos.txns.deleteTransaction('tx000001')).called(1);
      verify(repos.txns.getTransactions).called(1);
      await tester.tap(find.byKey(const ValueKey('fp-toast-action')));
      await tester.pump();
      await h.settle(tester);
      expect(row('tx000001'), findsOneWidget);
      expect(tester.getTopLeft(row('tx000001')).dy, before);
      verify(() => repos.txns.addTransactions(any())).called(1);
      verify(repos.txns.getTransactions).called(1);
      expect(h.haptics.calls, contains(HapticType.selection));
    });

    testWidgets('letting the toast expire keeps the row deleted', (
      tester,
    ) async {
      await open(tester, rows: 3);
      await swipe(tester, 'tx000002', -120);
      await tester.tap(deleteAction(tester));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await h.settle(tester);
      expect(find.text('Transaction deleted'), findsNothing);
      expect(row('tx000002'), findsNothing);
      verifyNever(() => repos.txns.addTransactions(any()));
    });

    testWidgets('deleting every row shows the empty state', (tester) async {
      await open(tester, rows: 1);
      await swipe(tester, 'tx000000', -120);
      await tester.tap(deleteAction(tester));
      await tester.pump();
      await h.settle(tester);
      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('a failed delete puts the row back with an error toast', (
      tester,
    ) async {
      await open(tester, rows: 3);
      when(
        () => repos.txns.deleteTransaction(any()),
      ).thenAnswer((_) async => const Failure('Storage is locked'));
      await swipe(tester, 'tx000000', -120);
      await tester.tap(deleteAction(tester));
      await tester.pump();
      await h.settle(tester);
      expect(row('tx000000'), findsOneWidget);
      expect(find.text('Storage is locked'), findsOneWidget);
      expect(h.haptics.calls, contains(HapticType.error));
    });
  });

  group('details sheet', () {
    testWidgets('tap opens a sheet with masked counterparty, amount and id', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(row('tx000002'));
      await tester.pump();
      await h.settle(tester);
      expect(find.byKey(const ValueKey('transaction-details')), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('transaction-details-counterparty')),
            )
            .data,
        'P••••••••••••n',
      );
      expect(find.text('Priya Raghavan'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('transaction-details-id')))
            .data,
        'tx000002',
      );
      expect(find.text('Sent'), findsWidgets);
      await tapButton(tester, 'Done');
      await h.settle(tester);
      expect(find.byKey(const ValueKey('transaction-details')), findsNothing);
      // The Details swipe action opens the same sheet.
      await swipe(tester, 'tx000000', -120);
      await tester.tap(detailsAction(tester));
      await tester.pump();
      await h.settle(tester);
      expect(find.byKey(const ValueKey('transaction-details')), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('transaction-details-counterparty')),
            )
            .data,
        'G•••••••••n',
      );
    });

    testWidgets('the sheet respects hide balance', (tester) async {
      await open(tester, settings: const AppSettings(hideBalance: true));
      await tester.tap(row('tx000000'));
      await tester.pump();
      await h.settle(tester);
      final amount = tester.widget<FpAmountText>(
        find.byKey(const ValueKey('transaction-details-amount')),
      );
      expect(amount.hide, FpAmountHide.mask);
    });
  });

  group('motion, navigation and accessibility', () {
    testWidgets('reduce motion: rows render and the swipe snaps instantly', (
      tester,
    ) async {
      await open(tester, rm: true);
      expect(find.byType(TransactionRow), findsWidgets);
      final gesture = await tester.startGesture(rowCenter(tester, 'tx000000'));
      await gesture.moveBy(const Offset(-120, 0));
      await gesture.up();
      await tester.pump();
      expect(foregroundDx(tester, 'tx000000'), closeTo(-144, 0.5));
    });

    testWidgets('back leaves to home when nothing can pop', (tester) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      await h.settle(tester);
      expect(h.location, AppRoutes.home);
    });

    testWidgets('1.3× text: no overflow, guidelines met', (tester) async {
      await open(tester, scale: 1.3);
      expect(tester.takeException(), isNull);
      await expectGuidelines(tester);
      await tester.tap(row('tx000000'));
      await tester.pump();
      await h.settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('relative day labels follow the injected clock', (
      tester,
    ) async {
      repos = InsightsRepos();
      await h.init(
        tester,
        signedIn: true,
        transactionRepository: repos.txns,
        userRepository: repos.users,
        cardRepository: repos.cards,
        notificationRepository: repos.notes,
        clock: Clock.fixed(insightsNow.add(const Duration(days: 40))),
      );
      await h.pump(tester, AppRoutes.transactions);
      await h.settle(tester);
      expect(find.text('TODAY'), findsNothing);
      expect(find.text('31 OCT'), findsOneWidget);
    });
  });
}
