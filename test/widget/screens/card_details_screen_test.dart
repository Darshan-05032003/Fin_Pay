import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    String id = 'c1',
    double scale = 1,
    bool rm = false,
  }) async {
    await repos.init(h, tester: tester);
    await h.pump(
      tester,
      AppRoutes.cardDetailsFor(id),
      textScale: scale,
      reduceMotion: rm,
    );
    await h.settle(tester);
  }

  testWidgets('loading, then content with the masked number only', (
    tester,
  ) async {
    final gate = Completer<Result<List<PaymentCard>>>();
    when(() => repos.cards.getCards()).thenAnswer((_) => gate.future);
    await open(tester);
    expect(find.byKey(const ValueKey('card-details-loading')), findsOneWidget);
    gate.complete(const Success(fixtureCards));
    await tester.pump();
    await h.settle(tester);
    expect(find.text('Card details'), findsOneWidget);
    expect(find.text('•••• •••• •••• 1111'), findsNWidgets(2));
    expect(find.textContaining('4111'), findsNothing);
    expect(find.textContaining('987'), findsNothing);
    expect(find.byKey(const ValueKey('card-freeze')), findsOneWidget);
    expect(find.text('REMOVE CARD'), findsOneWidget);
    expect(h.protector.enabled, isTrue);
  });

  testWidgets('error state retries; unknown id shows "Card not found"', (
    tester,
  ) async {
    when(
      () => repos.cards.getCards(),
    ).thenAnswer((_) async => const Failure('db'));
    await open(tester);
    expect(find.byKey(const ValueKey('card-details-error')), findsOneWidget);
    when(
      () => repos.cards.getCards(),
    ).thenAnswer((_) async => const Success(fixtureCards));
    await tapButton(tester, 'Retry');
    await h.settle(tester);
    expect(find.byKey(const ValueKey('card-details-error')), findsNothing);
    await h.dispose(tester);

    h = ScreenHarness();
    repos = HomeCardsRepos();
    await open(tester, id: 'nope');
    expect(find.byKey(const ValueKey('card-details-missing')), findsOneWidget);
    expect(find.text('Card not found'), findsOneWidget);
    await tapButton(tester, 'Back to cards');
    await h.settle(tester);
    expect(h.location, AppRoutes.cards);
  });

  testWidgets('copy puts only the last four digits on the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(tester);
    await tapButton(tester, 'Copy last 4');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(copied, '1111');
    expect(find.text('Last 4 digits copied'), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.light));
  });

  testWidgets('freeze toggles the overlay', (tester) async {
    await open(tester);
    expect(find.text('FROZEN'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('card-freeze')));
    await tester.pump();
    await h.settle(tester);
    expect(find.text('FROZEN'), findsOneWidget);
    expect(find.text('Payments are blocked on this device.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('card-freeze')));
    await tester.pump();
    await h.settle(tester);
    expect(find.text('FROZEN'), findsNothing);
  });

  testWidgets('flip and reveal the CVV on the details card', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('card-details-card')));
    await tester.pump();
    await h.settle(tester);
    expect(find.text('REVEAL CVV'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reveal-cvv-c1')));
    await tester.pump();
    await tester.pump();
    expect(find.text('987'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('987'), findsNothing);
  });

  testWidgets('recent card payments list only payments', (tester) async {
    await open(tester);
    expect(find.text('Grocery run'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Sent to Priya'), findsNothing);
  });

  testWidgets('remove: sheet, confirm, deleted, back to the stack', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('card-remove')));
    await tester.pump();
    await tapButton(tester, 'Remove card');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Remove this card?'), findsOneWidget);
    await tapButton(tester, 'Keep it');
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Remove this card?'), findsNothing);
    verifyNever(() => repos.cards.deleteCard(any()));
    await tapButton(tester, 'Remove card');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('card-remove-confirm')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    verify(() => repos.cards.deleteCard('c1')).called(1);
    await h.settle(tester);
    expect(find.text('Card removed'), findsOneWidget);
    expect(h.location, AppRoutes.cards);
  });

  testWidgets('a failed removal shows an error toast and stays', (
    tester,
  ) async {
    when(
      () => repos.cards.deleteCard('c1'),
    ).thenAnswer((_) async => const Failure('db locked'));
    await open(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('card-remove')));
    await tester.pump();
    await tapButton(tester, 'Remove card');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('card-remove-confirm')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('db locked'), findsOneWidget);
    expect(h.location, '/cards/c1');
    expect(h.haptics.calls, contains(HapticType.error));
  });

  testWidgets('reduce motion and 1.3×: no overflow, guidelines met', (
    tester,
  ) async {
    await open(tester, scale: 1.3, rm: true);
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
    await tester.tap(find.byKey(const ValueKey('card-details-card')));
    await tester.pump();
    expect(find.text('REVEAL CVV'), findsOneWidget);
    expect(find.byType(FpFlipCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
