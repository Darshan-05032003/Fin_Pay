import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/platform/motion_sensor.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_cubit.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_view.dart';
import 'package:fin_pay/screens/cards/widgets/payment_card_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  }) async {
    await repos.init(h, tester: tester);
    await h.pump(tester, AppRoutes.cards, textScale: scale, reduceMotion: rm);
    await h.settle(tester);
  }

  Finder cvvText() => find.byKey(const ValueKey('card-cvv-text'));

  String cvvShown(WidgetTester tester) =>
      tester.widget<Text>(cvvText()).data ?? '';

  Future<void> fanOut(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(RegExp('tap to fan out')));
    await tester.pump();
    await h.settle(tester);
  }

  Future<void> flipFocused(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('focused-card-c1')));
    await tester.pump();
    await h.settle(tester);
  }

  testWidgets('loading: skeleton while the repository is pending', (
    tester,
  ) async {
    final gate = Completer<Result<List<PaymentCard>>>();
    when(() => repos.cards.getCards()).thenAnswer((_) => gate.future);
    await open(tester);
    expect(find.byKey(const ValueKey('cards-loading')), findsOneWidget);
    gate.complete(const Success(fixtureCards));
    await tester.pump();
    await h.settle(tester);
    expect(find.byKey(const ValueKey('cards-loading')), findsNothing);
    expect(find.textContaining('3 cards'), findsOneWidget);
  });

  testWidgets('error: message and retry reloads', (tester) async {
    when(
      () => repos.cards.getCards(),
    ).thenAnswer((_) async => const Failure('db locked'));
    await open(tester);
    expect(find.byKey(const ValueKey('cards-error')), findsOneWidget);
    expect(find.text('db locked'), findsOneWidget);
    when(
      () => repos.cards.getCards(),
    ).thenAnswer((_) async => const Success(fixtureCards));
    await tapButton(tester, 'Retry');
    await h.settle(tester);
    expect(find.byKey(const ValueKey('cards-error')), findsNothing);
    verify(() => repos.cards.getCards()).called(2);
  });

  testWidgets('empty: "No cards yet" with a working add action', (
    tester,
  ) async {
    when(
      () => repos.cards.getCards(),
    ).thenAnswer((_) async => const Success([]));
    await open(tester);
    expect(find.byKey(const ValueKey('cards-empty')), findsOneWidget);
    expect(find.text('No cards yet'), findsOneWidget);
    await tapButton(tester, 'Add a card');
    await h.settle(tester);
    expect(h.location, AppRoutes.addCard);
  });

  testWidgets('content: pile shows every card masked, no PAN or CVV text', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(PaymentCardArt), findsNWidgets(3));
    expect(find.text('•••• •••• •••• 1111'), findsOneWidget);
    expect(find.textContaining('4111 1111'), findsNothing);
    expect(find.textContaining('987'), findsNothing);
    expect(find.textContaining('3 cards'), findsOneWidget);
    expect(find.text('Visa · 1111'), findsOneWidget);
    expect(h.protector.enabled, isTrue);
  });

  testWidgets('tap fans the pile into a carousel; Stack collapses it', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const ValueKey('card-carousel')), findsNothing);
    await fanOut(tester);
    expect(find.byKey(const ValueKey('card-carousel')), findsOneWidget);
    expect(find.text('Swipe to browse, tap to flip'), findsOneWidget);
    await tapButton(tester, 'Stack');
    await h.settle(tester);
    expect(find.byKey(const ValueKey('card-carousel')), findsNothing);
    expect(find.textContaining('3 cards'), findsOneWidget);
  });

  testWidgets('swipe between cards changes the focused summary', (
    tester,
  ) async {
    await open(tester);
    await fanOut(tester);
    await tester.drag(
      find.byKey(const ValueKey('card-carousel')),
      const Offset(-320, 0),
    );
    await tester.pump();
    await h.settle(tester);
    expect(find.text('Mastercard · 4444'), findsOneWidget);
    expect(find.byKey(const ValueKey('focused-card-c2')), findsOneWidget);
  });

  testWidgets('flip shows the back with a masked CVV; reveal fetches from '
      'secure storage and masks again after 5 s', (tester) async {
    await open(tester);
    await fanOut(tester);
    await flipFocused(tester);
    expect(cvvShown(tester), '•••');
    expect(find.text('REVEAL CVV'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reveal-cvv-c1')));
    await tester.pump();
    await tester.pump();
    verify(() => repos.cards.readCvv('c1')).called(1);
    expect(cvvShown(tester), '987');
    expect(find.text('HIDE CVV'), findsOneWidget);
    expect(find.byType(FpCountdownRing), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(cvvShown(tester), '987');
    await tester.pump(const Duration(seconds: 3));
    expect(cvvShown(tester), '•••');
    expect(find.text('REVEAL CVV'), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.light));
  });

  testWidgets('HIDE CVV masks at once; a missing vault entry is reported', (
    tester,
  ) async {
    await open(tester);
    await fanOut(tester);
    await flipFocused(tester);
    await tester.tap(find.byKey(const ValueKey('reveal-cvv-c1')));
    await tester.pump();
    await tester.pump();
    expect(cvvShown(tester), '987');
    await tester.tap(find.byKey(const ValueKey('reveal-cvv-c1')));
    await tester.pump();
    expect(cvvShown(tester), '•••');
    when(
      () => repos.cards.readCvv('c1'),
    ).thenAnswer((_) async => const Success(null));
    await tester.tap(find.byKey(const ValueKey('reveal-cvv-c1')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(cvvShown(tester), '•••');
  });

  testWidgets('backgrounding hides a revealed CVV and turns the card over', (
    tester,
  ) async {
    await open(tester);
    await fanOut(tester);
    await flipFocused(tester);
    await tester.tap(find.byKey(const ValueKey('reveal-cvv-c1')));
    await tester.pump();
    await tester.pump();
    expect(cvvShown(tester), '987');
    // `inactive` is the last state in which a frame is drawn before the
    // app-switcher thumbnail is taken.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await h.settle(tester);
    expect(cvvText(), findsNothing, reason: 'the front is showing again');
    [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    await h.settle(tester);
    expect(cvvText(), findsNothing, reason: 'still masked after resume');
  });

  testWidgets('sensor tilt drives the front card; off under reduce motion', (
    tester,
  ) async {
    await open(tester);
    await fanOut(tester);
    expect(h.sensor.listeners, 1);
    final card = tester.widget<FpTiltCard>(find.byType(FpTiltCard));
    expect(card.dragFallback, isFalse, reason: 'sensor available');
    h.sensor.emit(const Tilt(1, 0));
    await tester.pump();
    await tester.pump();
    expect(card.controller!.value.dx, greaterThan(0));
    final before = card.controller!.value.dx;
    h.sensor.emit(const Tilt(1, 0));
    await tester.pump();
    expect(card.controller!.value.dx, greaterThan(before), reason: 'damped');
    expect(card.controller!.value.dx, lessThanOrEqualTo(1));
    h.sensor.emit(const Tilt(50, -50));
    await tester.pump();
    expect(card.controller!.value.dx.abs(), lessThanOrEqualTo(1));
    expect(card.controller!.value.dy.abs(), lessThanOrEqualTo(1));
    // Switching tabs releases the sensor.
    h.router!.go(AppRoutes.home);
    await tester.pump();
    await h.settle(tester);
    expect(h.sensor.listeners, 0);
  });

  testWidgets('no sensor: drag fallback; reduce motion: no subscription', (
    tester,
  ) async {
    h = ScreenHarness();
    final sensor = FakeMotionSensor(available: false);
    await h.init(
      tester,
      signedIn: true,
      cardRepository: repos.cards,
      transactionRepository: repos.txns,
      userRepository: repos.users,
      motionSensor: sensor,
    );
    await h.pump(tester, AppRoutes.cards);
    await h.settle(tester);
    await fanOut(tester);
    expect(sensor.listeners, 0);
    final card = tester.widget<FpTiltCard>(find.byType(FpTiltCard));
    expect(card.dragFallback, isTrue);
    await h.dispose(tester);

    h = ScreenHarness();
    repos = HomeCardsRepos();
    await open(tester, rm: true);
    await fanOut(tester);
    expect(h.sensor.listeners, 0);
    expect(find.byType(FpTiltCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FpTiltCard),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              (w.decoration as BoxDecoration).gradient is RadialGradient,
        ),
      ),
      findsNothing,
      reason: 'no sheen under reduce motion',
    );
  });

  testWidgets('the focused summary opens card details; Add opens the form', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('cards-focused-summary')));
    await tester.pump();
    await h.settle(tester);
    expect(h.location, '/cards/c1');
    expect(find.text('Card details'), findsOneWidget);
    h.router!.pop();
    await h.settle(tester);
    await tester.tap(find.byKey(const ValueKey('cards-add')));
    await tester.pump();
    await h.settle(tester);
    expect(h.location, AppRoutes.addCard);
  });

  testWidgets('a newly added card enters the stack focused', (tester) async {
    await open(tester);
    final added = fixtureCards.first.copyWith(
      id: 'c9',
      cardNumber: '4012 8888 8888 1881',
    );
    when(
      () => repos.cards.getCards(),
    ).thenAnswer((_) async => Success([added, ...fixtureCards]));
    unawaited(h.router!.push(AppRoutes.addCard));
    await tester.pump();
    await h.settle(tester);
    h.router!.pop();
    await h.settle(tester);
    // Simulate the bloc reload that follows a successful add.
    final cards = tester.element(find.byType(CardStackView));
    cards.read<CardStackCubit>().cardsChanged(4, focusNewest: true);
    await tester.pump();
    await h.settle(tester);
    expect(cards.read<CardStackCubit>().state.focused, 0);
    expect(cards.read<CardStackCubit>().state.fanned, isTrue);
  });

  testWidgets('reduce motion: fan, flip and reveal still work', (tester) async {
    await open(tester, rm: true);
    await fanOut(tester);
    await flipFocused(tester);
    expect(cvvShown(tester), '•••');
    await tester.tap(find.byKey(const ValueKey('reveal-cvv-c1')));
    await tester.pump();
    await tester.pump();
    expect(cvvShown(tester), '987');
    expect(tester.takeException(), isNull);
  });

  testWidgets('1.3× text scale: no overflow, guidelines met', (tester) async {
    await open(tester, scale: 1.3);
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
    await fanOut(tester);
    await flipFocused(tester);
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });
}
