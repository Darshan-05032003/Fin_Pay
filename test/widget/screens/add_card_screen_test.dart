import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/cards/widgets/payment_card_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'home_cards_fixtures.dart';
import 'screen_harness.dart';

const ValueKey<String> _number = ValueKey('add-card-number');
const ValueKey<String> _name = ValueKey('add-card-name');
const ValueKey<String> _expiry = ValueKey('add-card-expiry');
const ValueKey<String> _cvv = ValueKey('add-card-cvv');

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
    String at = AppRoutes.addCard,
  }) async {
    await h.init(
      tester,
      signedIn: true,
      cardRepository: repos.cards,
      transactionRepository: repos.txns,
      userRepository: repos.users,
      clock: Clock.fixed(DateTime(2026, 10, 31, 12)),
    );
    await h.pump(tester, at, textScale: scale, reduceMotion: rm);
    await h.settle(tester);
  }

  Future<void> fill(
    WidgetTester tester, {
    String number = '4111 1111 1111 1111',
    String expiry = '12/30',
  }) async {
    await typeInto(tester, _number, number);
    await typeInto(tester, _name, 'Aarav Mehta');
    await typeInto(tester, _expiry, expiry);
    await typeInto(tester, _cvv, '321');
  }

  PaymentCardArt art(WidgetTester tester) =>
      tester.widget<PaymentCardArt>(find.byType(PaymentCardArt).first);

  testWidgets('content: preview, four fields, protected screen', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Add a card'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-card-preview')), findsOneWidget);
    expect(art(tester).number, '•••• •••• •••• ••••');
    for (final key in [_number, _name, _expiry, _cvv]) {
      expect(find.byKey(key), findsOneWidget);
    }
    expect(h.protector.enabled, isTrue);
    final cvvField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(_cvv),
        matching: find.byType(EditableText),
      ),
    );
    expect(cvvField.obscureText, isTrue);
    expect(cvvField.enableSuggestions, isFalse);
    expect(cvvField.autocorrect, isFalse);
    expect(cvvField.autofillHints, isNull);
    final numberField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(_number),
        matching: find.byType(EditableText),
      ),
    );
    expect(numberField.enableSuggestions, isFalse);
    expect(numberField.autocorrect, isFalse);
  });

  testWidgets('the preview updates per keystroke with the network', (
    tester,
  ) async {
    await open(tester);
    await typeInto(tester, _number, '4111 11');
    await tester.pump(const Duration(milliseconds: 300));
    expect(art(tester).number, '4111 11•• •••• ••••');
    expect(find.text('VISA'), findsOneWidget);
    expect(find.text('Visa detected'), findsOneWidget);
    await typeInto(tester, _number, '5555');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('MASTERCARD'), findsOneWidget);
    await typeInto(tester, _number, '6521');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RUPAY'), findsOneWidget);
    await typeInto(tester, _name, 'aarav mehta');
    await tester.pump();
    expect(art(tester).holder, 'AARAV MEHTA');
    await typeInto(tester, _expiry, '1230');
    await tester.pump();
    expect(art(tester).expiry, '12/30');
    expect(find.text('12/30'), findsWidgets);
  });

  testWidgets('focusing the CVV flips the preview; leaving flips it back', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('AUTHORISED SIGNATURE'), findsNothing);
    await tester.tap(find.byKey(_cvv));
    await tester.pump();
    await h.settle(tester);
    expect(find.text('AUTHORISED SIGNATURE'), findsOneWidget);
    await typeInto(tester, _cvv, '32');
    expect(find.text('••'), findsOneWidget);
    await tester.tap(find.byKey(_name));
    await tester.pump();
    await h.settle(tester);
    expect(find.text('AUTHORISED SIGNATURE'), findsNothing);
  });

  testWidgets('empty submit: inline errors, shake and error haptic', (
    tester,
  ) async {
    await open(tester);
    await tapButton(tester, 'Add card');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Card number is required'), findsOneWidget);
    expect(find.text('Name on card is required'), findsOneWidget);
    expect(find.text('Expiry is required'), findsOneWidget);
    expect(find.text('CVV is required'), findsOneWidget);
    expect(h.haptics.calls, contains(HapticType.error));
    expect(
      tester.widget<FpShake>(find.byType(FpShake).first).controller.shakeCount,
      1,
    );
    verifyNever(() => repos.cards.addCard(any()));
  });

  testWidgets('Luhn, expiry and CVV errors are specific', (tester) async {
    await open(tester);
    await fill(tester, number: '4111 1111 1111 1112', expiry: '09/26');
    await typeInto(tester, _cvv, '12');
    await tapButton(tester, 'Add card');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Check the card number'), findsOneWidget);
    expect(find.text('This card has expired'), findsOneWidget);
    expect(find.text('CVV is 3 digits'), findsOneWidget);
  });

  testWidgets('valid card: stored once (PAN + CVV to the repository), '
      'success toast, back to the stack', (tester) async {
    await open(tester, at: AppRoutes.cards);
    await tester.tap(find.byKey(const ValueKey('cards-add')));
    await tester.pump();
    await h.settle(tester);
    expect(h.location, AppRoutes.addCard);
    final stored = <PaymentCard>[];
    when(() => repos.cards.addCard(any())).thenAnswer((invocation) async {
      stored.add(invocation.positionalArguments.first as PaymentCard);
      return const Success(null);
    });
    when(
      () => repos.cards.getCards(),
    ).thenAnswer((_) async => Success([...stored, ...fixtureCards]));
    await fill(tester);
    await tapButton(tester, 'Add card');
    await tester.pump();
    await tester.pump();
    await h.settle(tester);
    expect(stored, hasLength(1));
    expect(stored.single.cardNumber, '4111111111111111');
    expect(stored.single.cvv, '321');
    expect(stored.single.cardType, CardType.visa);
    expect(h.haptics.calls, contains(HapticType.success));
    expect(find.text('Card added'), findsOneWidget);
    expect(h.location, AppRoutes.cards);
    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('4 cards'), findsOneWidget);
  });

  testWidgets('50 rapid taps on Add card store one card', (tester) async {
    await open(tester);
    final gate = Completer<Result<void>>();
    when(() => repos.cards.addCard(any())).thenAnswer((_) => gate.future);
    await fill(tester);
    final center = tester.getCenter(
      find.byKey(const ValueKey('add-card-submit')),
    );
    for (var i = 0; i < 50; i++) {
      await tester.tapAt(center);
    }
    await tester.pump();
    expect(find.byKey(const ValueKey('fp-button-spinner')), findsOneWidget);
    gate.complete(const Success(null));
    await tester.pump();
    await h.settle(tester);
    verify(() => repos.cards.addCard(any())).called(1);
  });

  testWidgets('a duplicate (same last 4 and expiry) is refused inline', (
    tester,
  ) async {
    await open(tester, at: AppRoutes.cards);
    unawaited(h.router!.push(AppRoutes.addCard));
    await tester.pump();
    await h.settle(tester);
    await fill(tester, number: '5555 5555 5555 4444', expiry: '03/27');
    await tapButton(tester, 'Add card');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('This card is already in your wallet'), findsOneWidget);
    verifyNever(() => repos.cards.addCard(any()));
  });

  testWidgets('a storage failure shows under the form', (tester) async {
    await open(tester);
    when(
      () => repos.cards.addCard(any()),
    ).thenAnswer((_) async => const Failure('Could not store card securely'));
    await fill(tester);
    await tapButton(tester, 'Add card');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Could not store card securely'), findsOneWidget);
    expect(h.location, AppRoutes.addCard);
  });

  testWidgets('backgrounding turns the preview to the front', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(_cvv));
    await tester.pump();
    await h.settle(tester);
    expect(find.text('AUTHORISED SIGNATURE'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await h.settle(tester);
    expect(find.text('AUTHORISED SIGNATURE'), findsNothing);
    [
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();
    await h.settle(tester);
    expect(find.text('AUTHORISED SIGNATURE'), findsNothing);
  });

  testWidgets('hostile input never throws, never stores, never leaks', (
    tester,
  ) async {
    await open(tester);
    await typeInto(tester, _number, '\u202E${'4' * 10000}😀४१११');
    await typeInto(tester, _name, '${'x' * 5000}\u0000<script>');
    await typeInto(tester, _expiry, '१२/२८%s%n');
    await typeInto(tester, _cvv, "' OR 1=1 --");
    await tapButton(tester, 'Add card');
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(art(tester).number, '4444 4444 4444 4444');
    verifyNever(() => repos.cards.addCard(any()));
    expect(find.textContaining('script'), findsNothing);
  });

  testWidgets('deep link to /cards/add signed out goes to login', (
    tester,
  ) async {
    await h.init(tester);
    await h.pump(tester, AppRoutes.addCard);
    await h.settle(tester);
    expect(h.location, AppRoutes.login);
  });

  testWidgets('reduce motion: preview still flips and the form submits', (
    tester,
  ) async {
    await open(tester, rm: true);
    await tester.tap(find.byKey(_cvv));
    await tester.pump();
    expect(find.text('AUTHORISED SIGNATURE'), findsOneWidget);
    await fill(tester);
    await tapButton(tester, 'Add card');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    verify(() => repos.cards.addCard(any())).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('1.3× text scale: no overflow, guidelines met', (tester) async {
    await open(tester, scale: 1.3);
    await fill(tester, number: '4111 1111 1111 1112');
    await tapButton(tester, 'Add card');
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await expectGuidelines(tester);
  });
}
