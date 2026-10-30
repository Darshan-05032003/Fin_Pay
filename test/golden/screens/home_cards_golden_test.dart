@Tags(['golden'])
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget/screens/home_cards_fixtures.dart';
import '../../widget/screens/screen_harness.dart';

/// Home, cards, add card and card details in their main states, at 1.0×
/// and 1.3×. Baselines live in `goldens/<screen>_<state>_<scale>.png`;
/// regenerate with `flutter test --update-goldens test/golden/screens`
/// only when a change is intended.
void main() {
  late ScreenHarness h;
  late HomeCardsRepos repos;
  final fixedClock = Clock.fixed(DateTime(2026, 10, 31, 9, 30));

  setUp(() {
    h = ScreenHarness();
    repos = HomeCardsRepos();
  });

  Future<void> boot(
    WidgetTester tester, {
    AppSettings settings = AppSettings.defaults,
  }) => h.init(
    tester,
    signedIn: true,
    initialSettings: settings,
    cardRepository: repos.cards,
    transactionRepository: repos.txns,
    userRepository: repos.users,
    clock: fixedClock,
  );

  Future<void> snap(WidgetTester tester, String name, double scale) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    final s = scale.toStringAsFixed(1).replaceAll('.', '_');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/${name}_$s.png'),
    );
  }

  Future<void> fanOut(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(RegExp('tap to fan out')));
    await tester.pump();
    await h.settle(tester);
  }

  for (final scale in [1.0, 1.3]) {
    group('${scale}x', () {
      testWidgets('home content and hidden balance', (tester) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.home, textScale: scale);
        await snap(tester, 'home_content', scale);
        await tester.tap(find.byKey(const ValueKey('home-hide-balance')));
        await snap(tester, 'home_hidden', scale);
        await tester.drag(
          find.byKey(const ValueKey('home-scroll')),
          const Offset(0, -900),
        );
        await snap(tester, 'home_collapsed', scale);
      });

      testWidgets('home empty and loading', (tester) async {
        await boot(tester);
        when(
          () => repos.txns.getTransactions(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => const Success([]));
        when(
          () => repos.cards.getCards(),
        ).thenAnswer((_) async => const Success([]));
        await h.pump(tester, AppRoutes.home, textScale: scale);
        await tester.drag(
          find.byKey(const ValueKey('home-scroll')),
          const Offset(0, -500),
        );
        await snap(tester, 'home_empty', scale);
        await h.dispose(tester);

        h = ScreenHarness();
        repos = HomeCardsRepos();
        await boot(tester);
        when(
          () => repos.users.getCurrentUser(),
        ).thenAnswer((_) => Completer<Result<User?>>().future);
        when(
          () => repos.txns.getTransactions(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) => Completer<Result<List<Transaction>>>().future);
        when(
          () => repos.cards.getCards(),
        ).thenAnswer((_) => Completer<Result<List<PaymentCard>>>().future);
        await h.pump(tester, AppRoutes.home, textScale: scale);
        await snap(tester, 'home_loading', scale);
      });

      testWidgets('cards stack, fanned, flipped and empty', (tester) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.cards, textScale: scale);
        await snap(tester, 'cards_stack', scale);
        await fanOut(tester);
        await snap(tester, 'cards_fanned', scale);
        await tester.tap(find.byKey(const ValueKey('focused-card-c1')));
        await snap(tester, 'cards_flipped', scale);
        await h.dispose(tester);

        h = ScreenHarness();
        repos = HomeCardsRepos();
        await boot(tester);
        when(
          () => repos.cards.getCards(),
        ).thenAnswer((_) async => const Success([]));
        await h.pump(tester, AppRoutes.cards, textScale: scale);
        await snap(tester, 'cards_empty', scale);
      });

      testWidgets('add card empty, Visa, Mastercard, RuPay, error, back', (
        tester,
      ) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.addCard, textScale: scale);
        await snap(tester, 'add_card_empty', scale);
        await typeInto(
          tester,
          const ValueKey('add-card-number'),
          '4111 1111 1111 1111',
        );
        await typeInto(tester, const ValueKey('add-card-name'), 'Aarav Mehta');
        await typeInto(tester, const ValueKey('add-card-expiry'), '12/30');
        await snap(tester, 'add_card_visa', scale);
        await typeInto(
          tester,
          const ValueKey('add-card-number'),
          '5555 5555 5555 4444',
        );
        await snap(tester, 'add_card_mastercard', scale);
        await typeInto(
          tester,
          const ValueKey('add-card-number'),
          '6521 0200 0000 0005',
        );
        await snap(tester, 'add_card_rupay', scale);
        await typeInto(
          tester,
          const ValueKey('add-card-number'),
          '4111 1111 1111 1112',
        );
        await typeInto(tester, const ValueKey('add-card-expiry'), '09/26');
        await tapButton(tester, 'Add card');
        await snap(tester, 'add_card_error', scale);
        await tester.tap(find.byKey(const ValueKey('add-card-cvv')));
        await typeInto(tester, const ValueKey('add-card-cvv'), '32');
        await snap(tester, 'add_card_back', scale);
      });

      testWidgets('card details front and back', (tester) async {
        await boot(tester);
        await h.pump(tester, AppRoutes.cardDetailsFor('c1'), textScale: scale);
        await snap(tester, 'card_details', scale);
        await tester.tap(find.byKey(const ValueKey('card-freeze')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('card-details-card')));
        await snap(tester, 'card_details_back_frozen', scale);
      });
    });
  }
}
