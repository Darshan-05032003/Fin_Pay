import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/home/home_header_math.dart';
import 'package:fin_pay/screens/home/widgets/balance_header.dart';
import 'package:fin_pay/screens/home/widgets/offers_carousel.dart';
import 'package:fin_pay/screens/home/widgets/transaction_row.dart';
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'home_cards_fixtures.dart';
import 'screen_harness.dart';

void main() {
  late ScreenHarness h;
  late HomeCardsRepos repos;

  setUp(() {
    h = ScreenHarness();
    repos = HomeCardsRepos();
  });

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    bool rm = false,
    AppSettings settings = AppSettings.defaults,
  }) async {
    await h.init(
      tester,
      signedIn: true,
      initialSettings: settings,
      cardRepository: repos.cards,
      transactionRepository: repos.txns,
      userRepository: repos.users,
    );
    await h.pump(tester, AppRoutes.home, textScale: scale, reduceMotion: rm);
    await h.settle(tester);
    // The odometer count-up runs about half a second; let it finish.
    await tester.pump(const Duration(seconds: 2));
  }

  Finder balance() => find.byKey(const ValueKey('home-balance'));

  Finder header() => find.byKey(const ValueKey('home-header-body'));

  /// Slivers below the fold are only built once scrolled into view.
  Future<void> scrollToRecent(WidgetTester tester) async {
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
    await tester.pump();
    await h.settle(tester);
  }

  String balanceLabel(WidgetTester tester) =>
      tester.getSemantics(balance()).label;

  testWidgets('content: greeting, counted-up balance, actions, card, offers, '
      'five recent rows', (tester) async {
    await open(tester);
    expect(find.text('Aarav Mehta'), findsOneWidget);
    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('AVAILABLE BALANCE'), findsOneWidget);
    expect(balanceLabel(tester), 'Available balance ₹56,246.90');
    for (final key in ['send', 'add-card', 'stats', 'history']) {
      expect(find.byKey(ValueKey('home-action-$key')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('home-card-preview')), findsOneWidget);
    expect(find.text('•••• •••• •••• 1111'), findsOneWidget);
    expect(find.textContaining('4111'), findsNothing);
    expect(find.byKey(const ValueKey('home-offers')), findsOneWidget);
    expect(find.text('5% back on groceries'), findsOneWidget);
    await scrollToRecent(tester);
    expect(find.byType(TransactionRow), findsNWidgets(5));
    expect(find.text('Grocery run'), findsOneWidget);
    expect(find.text('Electricity bill'), findsNothing, reason: 'sixth');
    expect(find.text('+₹1,25,000.00'), findsOneWidget);
    expect(find.text('−₹1,849.00'), findsOneWidget);
    expect(h.protector.enabled, isTrue);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('the balance counts up from zero on first load', (tester) async {
    await h.init(
      tester,
      signedIn: true,
      cardRepository: repos.cards,
      transactionRepository: repos.txns,
      userRepository: repos.users,
    );
    await h.pump(tester, AppRoutes.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final amount = tester.widget<FpAmountText>(balance());
    expect(amount.animateFirstBuild, isTrue);
    expect(amount.paise, 5624690);
    await tester.pump(const Duration(seconds: 3));
    expect(balanceLabel(tester), 'Available balance ₹56,246.90');
  });

  testWidgets('loading: skeletons for balance, card and transactions', (
    tester,
  ) async {
    final userGate = Completer<Result<User?>>();
    final txGate = Completer<Result<List<Transaction>>>();
    final cardGate = Completer<Result<List<PaymentCard>>>();
    when(() => repos.users.getCurrentUser()).thenAnswer((_) => userGate.future);
    when(
      () => repos.txns.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => txGate.future);
    when(() => repos.cards.getCards()).thenAnswer((_) => cardGate.future);
    await open(tester);
    expect(find.byKey(const ValueKey('home-balance-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-card-loading')), findsOneWidget);
    await scrollToRecent(tester);
    expect(find.byKey(const ValueKey('home-recent-loading')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('home-scroll')),
      const Offset(0, 1000),
    );
    await tester.pump();
    userGate.complete(Success(harnessUser));
    txGate.complete(Success(repos.transactions));
    cardGate.complete(const Success(fixtureCards));
    await tester.pump();
    await h.settle(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('home-balance-loading')), findsNothing);
    expect(find.byKey(const ValueKey('home-card-loading')), findsNothing);
    await scrollToRecent(tester);
    expect(find.byKey(const ValueKey('home-recent-loading')), findsNothing);
    expect(find.byType(TransactionRow), findsNWidgets(5));
  });

  testWidgets('empty: no transactions, no cards, no user', (tester) async {
    when(
      () => repos.txns.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Success([]));
    when(
      () => repos.cards.getCards(),
    ).thenAnswer((_) async => const Success([]));
    when(
      () => repos.users.getCurrentUser(),
    ).thenAnswer((_) async => const Success(null));
    await open(tester);
    expect(find.byKey(const ValueKey('home-card-empty')), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(balanceLabel(tester), '₹0.00');
    await scrollToRecent(tester);
    expect(find.byKey(const ValueKey('home-recent-empty')), findsOneWidget);
    expect(find.text('No transactions yet'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('home-scroll')),
      const Offset(0, 1000),
    );
    await tester.pump();
    await h.settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-card-empty')));
    await tester.pump();
    await h.settle(tester);
    expect(h.location, AppRoutes.addCard);
  });

  testWidgets('error: transactions and balance retry', (tester) async {
    when(
      () => repos.txns.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Failure('db locked'));
    when(
      () => repos.users.getCurrentUser(),
    ).thenAnswer((_) async => const Failure('no db'));
    when(
      () => repos.cards.getCards(),
    ).thenAnswer((_) async => const Failure('no db'));
    await open(tester);
    expect(find.byKey(const ValueKey('home-balance-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-card-error')), findsOneWidget);
    await scrollToRecent(tester);
    expect(find.byKey(const ValueKey('home-recent-error')), findsOneWidget);
    expect(find.text('db locked'), findsOneWidget);
    when(
      () => repos.txns.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => Success(repos.transactions));
    when(
      () => repos.users.getCurrentUser(),
    ).thenAnswer((_) async => Success(harnessUser));
    await tapButton(tester, 'Retry');
    await tester.pump();
    await h.settle(tester);
    expect(find.byType(TransactionRow), findsNWidgets(5));
    await tester.drag(
      find.byKey(const ValueKey('home-scroll')),
      const Offset(0, 1000),
    );
    await tester.pump();
    await h.settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-balance-error')));
    await tester.pump();
    await h.settle(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(balanceLabel(tester), 'Available balance ₹56,246.90');
  });

  testWidgets('hide balance: masks the balance and the row amounts, persists '
      'the setting, and toggles back', (tester) async {
    await open(tester);
    expect(find.text(FpAmountText.masked), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-hide-balance')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(h.settings.state.hideBalance, isTrue);
    expect(h.settingsRepo.settings.hideBalance, isTrue);
    expect(h.settingsRepo.saves, 1);
    expect(balanceLabel(tester), 'Balance hidden');
    await scrollToRecent(tester);
    expect(find.text(FpAmountText.masked), findsNWidgets(6));
    expect(find.text('+₹1,25,000.00'), findsNothing);
    expect(h.haptics.calls, contains(HapticType.light));
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('home-hide-balance')))
          .label,
      'Show balance',
    );
    await tester.tap(find.byKey(const ValueKey('home-hide-balance')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(h.settingsRepo.saves, 2);
    expect(find.text(FpAmountText.masked), findsNothing);
    expect(find.text('+₹1,25,000.00'), findsOneWidget);
    expect(balanceLabel(tester), 'Available balance ₹56,246.90');
  });

  testWidgets('hide balance already on: masked from the first frame', (
    tester,
  ) async {
    await open(tester, settings: const AppSettings(hideBalance: true));
    expect(balanceLabel(tester), 'Balance hidden');
    await scrollToRecent(tester);
    expect(find.text(FpAmountText.masked), findsNWidgets(6));
  });

  testWidgets('scrolling collapses the header: the balance shrinks and docks', (
    tester,
  ) async {
    await open(tester);
    final expanded = tester.getSize(header());
    expect(expanded.height, HomeHeaderMath.expandedHeight(0));
    final before = tester.getTopLeft(balance());
    await tester.drag(
      find.byKey(const ValueKey('home-scroll')),
      const Offset(0, -400),
    );
    await tester.pump();
    await h.settle(tester);
    final collapsed = tester.getSize(header());
    expect(collapsed.height, HomeHeaderMath.collapsedHeight(0));
    final scale = tester
        .widget<Transform>(
          find.ancestor(of: balance(), matching: find.byType(Transform)).first,
        )
        .transform
        .entry(0, 0);
    expect(scale, closeTo(HomeHeaderMath.dockedScale, 1e-6));
    final after = tester.getTopLeft(balance());
    expect(after.dy, lessThan(before.dy));
    expect(find.byType(BalanceHeader), findsOneWidget);
    // The eye is still a 48 dp target in the bar.
    final eye = tester.getSize(find.byKey(const ValueKey('home-hide-balance')));
    expect(eye.height, greaterThanOrEqualTo(FpSpacing.minTapTarget));
  });

  testWidgets('pull to refresh reloads every bloc and plays a haptic', (
    tester,
  ) async {
    await open(tester);
    await tester.drag(
      find.byKey(const ValueKey('home-scroll')),
      const Offset(0, 220),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.haptics.calls, contains(HapticType.medium));
    await h.settle(tester);
    await tester.pump(const Duration(seconds: 2));
    verify(() => repos.users.getCurrentUser()).called(2);
    verify(() => repos.cards.getCards()).called(2);
    verify(
      () => repos.txns.getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(2);
    await scrollToRecent(tester);
    expect(find.byType(TransactionRow), findsNWidgets(5));
  });

  testWidgets('quick actions and links navigate', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('home-action-add-card')));
    await tester.pump();
    await h.settle(tester);
    expect(h.location, AppRoutes.addCard);
    h.router!.pop();
    await h.settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-action-stats')));
    await tester.pump();
    await h.settle(tester);
    await h.flush(tester, rounds: 3);
    expect(h.location, AppRoutes.statistics);
    h.router!.go(AppRoutes.home);
    await h.settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-card-preview')));
    await tester.pump();
    await h.settle(tester);
    expect(h.location, '/cards/c1');
    expect(find.text('Card details'), findsOneWidget);
    h.router!.pop();
    await h.settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-all-cards')));
    await tester.pump();
    await h.settle(tester);
    expect(h.location, AppRoutes.cards);
  });

  testWidgets('offers: swiping moves the page; flat under reduce motion', (
    tester,
  ) async {
    await open(tester);
    final offers = find.byKey(const ValueKey('home-offers'));
    expect(find.byKey(const ValueKey('offer-tilt-0')), findsOneWidget);
    await tester.drag(offers, const Offset(-300, 0));
    await tester.pump();
    await h.settle(tester);
    final second = find.byKey(const ValueKey('offer-transfers'));
    expect(second, findsOneWidget);
    expect(tester.getTopLeft(second).dx, lessThan(60));
    await h.dispose(tester);

    h = ScreenHarness();
    repos = HomeCardsRepos();
    await open(tester, rm: true);
    expect(find.byKey(const ValueKey('offer-tilt-0')), findsNothing);
    expect(find.text('5% back on groceries'), findsOneWidget);
  });

  testWidgets('re-selecting the home tab scrolls back to the top', (
    tester,
  ) async {
    await open(tester);
    await tester.drag(
      find.byKey(const ValueKey('home-scroll')),
      const Offset(0, -400),
    );
    await tester.pump();
    await h.settle(tester);
    expect(tester.getSize(header()).height, HomeHeaderMath.collapsedHeight(0));
    await tester.tap(
      find.descendant(
        of: find.byType(FpBottomNav),
        matching: find.text('Home'),
      ),
    );
    await tester.pump();
    await h.settle(tester);
    expect(tester.getSize(header()).height, HomeHeaderMath.expandedHeight(0));
    expect(
      AppShell.reselectOf(tester.element(find.byType(BalanceHeader)))!.count,
      1,
    );
  });

  testWidgets('reduce motion: no count-up, everything still renders', (
    tester,
  ) async {
    await h.init(
      tester,
      signedIn: true,
      cardRepository: repos.cards,
      transactionRepository: repos.txns,
      userRepository: repos.users,
    );
    await h.pump(tester, AppRoutes.home, reduceMotion: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(balanceLabel(tester), 'Available balance ₹56,246.90');
    await scrollToRecent(tester);
    expect(find.byType(TransactionRow), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('1.3× text scale: no overflow, guidelines met', (tester) async {
    await open(tester, scale: 1.3);
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
    await tester.drag(
      find.byKey(const ValueKey('home-scroll')),
      const Offset(0, -400),
    );
    await tester.pump();
    await h.settle(tester);
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });

  testWidgets('a huge balance fits at 1.3×', (tester) async {
    when(() => repos.users.getCurrentUser()).thenAnswer(
      (_) async =>
          Success(harnessUser.copyWith(balance: const Money.paise(9999999999))),
    );
    await open(tester, scale: 1.3);
    expect(balanceLabel(tester), 'Available balance ₹9,99,99,999.99');
    expect(tester.takeException(), isNull);
  });

  test('Offer.demo copy is original and the badges are drawn', () {
    expect(Offer.demo, hasLength(3));
    expect(Offer.demo.map((o) => o.badge).toSet(), OfferBadge.values.toSet());
  });
}
