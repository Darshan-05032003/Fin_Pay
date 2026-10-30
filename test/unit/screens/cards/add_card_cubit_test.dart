import 'dart:async';
import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/screens/cards/add_card/add_card_cubit.dart';
import 'package:fin_pay/screens/cards/add_card/card_validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements ICardRepository {}

void main() {
  late MockCardRepository repo;
  late CardBloc cards;
  final clock = Clock.fixed(DateTime(2026, 10, 31, 12));
  final stored = <PaymentCard>[];

  const existing = PaymentCard(
    id: 'c0',
    cardNumber: '**** **** **** 4444',
    cardHolderName: 'AARAV',
    expireDate: '12/28',
    cvv: '',
    cardType: CardType.mastercard,
    balance: Money.zero,
  );

  setUpAll(() => registerFallbackValue(existing));

  setUp(() {
    Logger.sink = (_) {};
    stored.clear();
    repo = MockCardRepository();
    when(
      () => repo.getCards(),
    ).thenAnswer((_) async => Success([existing, ...stored]));
    when(() => repo.addCard(any())).thenAnswer((invocation) async {
      stored.add(invocation.positionalArguments.first as PaymentCard);
      return const Success(null);
    });
    cards = CardBloc(repository: repo, maskSensitive: true);
  });

  tearDown(() => cards.close());

  AddCardCubit build() =>
      AddCardCubit(cards: cards, clock: clock, random: Random(1));

  void fillValid(AddCardCubit c, {String number = '4111 1111 1111 1111'}) => c
    ..numberChanged(number)
    ..nameChanged('Aarav Mehta')
    ..expiryChanged('1228')
    ..cvvChanged('123');

  test('initial state', () {
    final c = build();
    expect(c.state, const AddCardState());
    expect(c.state.canSubmit, isTrue);
    expect(c.state.previewNumber, '•••• •••• •••• ••••');
    unawaited(c.close());
  });

  blocTest<AddCardCubit, AddCardState>(
    'typing detects the network per keystroke and grows the preview',
    build: build,
    act: (c) => c
      ..numberChanged('4')
      ..numberChanged('41 11')
      ..numberChanged('5555')
      ..numberChanged('2221 00')
      ..numberChanged('6521'),
    expect: () => const [
      AddCardState(number: '4', network: CardNetwork.visa),
      AddCardState(number: '4111', network: CardNetwork.visa),
      AddCardState(number: '5555', network: CardNetwork.mastercard),
      AddCardState(number: '222100', network: CardNetwork.mastercard),
      AddCardState(number: '6521', network: CardNetwork.rupay),
    ],
    verify: (c) => expect(c.state.previewNumber, '6521 •••• •••• ••••'),
  );

  blocTest<AddCardCubit, AddCardState>(
    'the CVV never appears in the state, only its length',
    build: build,
    act: (c) => c
      ..cvvChanged('98')
      ..cvvChanged('987'),
    expect: () => const [
      AddCardState(cvvLength: 2),
      AddCardState(cvvLength: 3),
    ],
    verify: (c) {
      expect(c.state.toString(), isNot(contains('987')));
      expect(c.state.props.join(','), isNot(contains('987')));
    },
  );

  blocTest<AddCardCubit, AddCardState>(
    'CVV focus flips the preview; hideBack turns it over again',
    build: build,
    act: (c) => c
      ..cvvFocusChanged(focused: true)
      ..cvvFocusChanged(focused: true)
      ..hideBack(),
    expect: () => const [AddCardState(cvvFocused: true), AddCardState()],
  );

  blocTest<AddCardCubit, AddCardState>(
    'empty submit: every field error, failure status, nothing stored',
    build: build,
    act: (c) => c.submit(),
    expect: () => const [
      AddCardState(
        submitted: true,
        numberError: 'Card number is required',
        nameError: 'Name on card is required',
        expiryError: 'Expiry is required',
        cvvError: 'CVV is required',
        status: AddCardStatus.failure,
        failures: 1,
      ),
    ],
    verify: (_) => verifyNever(() => repo.addCard(any())),
  );

  blocTest<AddCardCubit, AddCardState>(
    'errors go live after the first submit',
    build: build,
    act: (c) async {
      await c.submit();
      c
        ..numberChanged('4111 1111 1111 1112')
        ..numberChanged('4111 1111 1111 1111')
        ..expiryChanged('0926')
        ..expiryChanged('0930');
    },
    skip: 1,
    expect: () => [
      isA<AddCardState>().having(
        (s) => s.numberError,
        'numberError',
        'Check the card number',
      ),
      isA<AddCardState>().having((s) => s.numberError, 'numberError', isNull),
      isA<AddCardState>().having(
        (s) => s.expiryError,
        'expiryError',
        'This card has expired',
      ),
      isA<AddCardState>().having((s) => s.expiryError, 'expiryError', isNull),
    ],
  );

  blocTest<AddCardCubit, AddCardState>(
    'a valid card is stored once with PAN and CVV, then success',
    build: build,
    act: (c) async {
      fillValid(c);
      await c.submit();
    },
    skip: 4,
    expect: () => [
      isA<AddCardState>().having(
        (s) => s.status,
        'status',
        AddCardStatus.submitting,
      ),
      isA<AddCardState>()
          .having((s) => s.status, 'status', AddCardStatus.success)
          .having((s) => s.addedCardId, 'addedCardId', startsWith('card-'))
          .having((s) => s.cvvLength, 'cvvLength', 0),
    ],
    verify: (c) {
      final saved =
          verify(() => repo.addCard(captureAny())).captured.single
              as PaymentCard;
      expect(saved.cardNumber, '4111111111111111');
      expect(saved.cvv, '123');
      expect(saved.cardHolderName, 'AARAV MEHTA');
      expect(saved.expireDate, '12/28');
      expect(saved.cardType, CardType.visa);
      expect(saved.id, c.state.addedCardId);
      expect(cards.state, isA<CardContent>());
    },
  );

  blocTest<AddCardCubit, AddCardState>(
    'a card with the same last four digits and expiry is a duplicate',
    build: build,
    seed: () => const AddCardState(),
    setUp: () async {
      cards.add(const LoadCardsEvent());
      await cards.stream.firstWhere((s) => s is CardContent);
    },
    act: (c) async {
      fillValid(c, number: '5555 5555 5555 4444');
      await c.submit();
    },
    skip: 4,
    expect: () => [
      isA<AddCardState>()
          .having(
            (s) => s.numberError,
            'numberError',
            AddCardCubit.duplicateMessage,
          )
          .having((s) => s.status, 'status', AddCardStatus.failure),
    ],
    verify: (_) => verifyNever(() => repo.addCard(any())),
  );

  test('1,000 submits of the same card store exactly one row', () async {
    cards.add(const LoadCardsEvent());
    await cards.stream.firstWhere((s) => s is CardContent);
    final c = build();
    fillValid(c);
    final futures = <Future<void>>[];
    for (var i = 0; i < 1000; i++) {
      futures.add(c.submit());
    }
    await Future.wait(futures);
    expect(c.state.status, AddCardStatus.success);
    verify(() => repo.addCard(any())).called(1);
    // A finished form never submits again.
    expect(c.state.canSubmit, isFalse);
    await c.submit();
    verifyNever(() => repo.addCard(any()));
    expect(stored, hasLength(1));
    await c.close();
  });

  blocTest<AddCardCubit, AddCardState>(
    'a storage failure is reported under the form',
    build: () {
      when(
        () => repo.addCard(any()),
      ).thenAnswer((_) async => const Failure('keystore unavailable'));
      return build();
    },
    act: (c) async {
      fillValid(c);
      await c.submit();
    },
    skip: 5,
    expect: () => [
      isA<AddCardState>()
          .having((s) => s.status, 'status', AddCardStatus.failure)
          .having((s) => s.message, 'message', 'keystore unavailable')
          .having((s) => s.failures, 'failures', 1),
    ],
  );

  test('a bloc that never answers times out into a failure', () async {
    final silent = CardBloc(repository: repo);
    final c = AddCardCubit(
      cards: silent,
      clock: clock,
      timeout: const Duration(milliseconds: 50),
    );
    await silent.close();
    fillValid(c);
    await c.submit();
    expect(c.state.status, AddCardStatus.failure);
    expect(c.state.message, contains('Could not save'));
    await c.close();
  });

  test('hostile input never throws and never stores', () async {
    final c = build()
      ..numberChanged('\u202E' * 5000)
      ..numberChanged('😀' * 5000)
      ..numberChanged('४१११ ١١١١')
      ..nameChanged('x' * 100000)
      ..expiryChanged('१२/२८')
      ..cvvChanged("' OR 1=1 --");
    expect(c.state.number, isEmpty);
    expect(c.state.name, hasLength(CardValidators.maxNameLength));
    expect(c.state.expiry, isEmpty);
    expect(c.state.cvvLength, 2, reason: 'only the two digits survive');
    await c.submit();
    expect(c.state.status, AddCardStatus.failure);
    verifyNever(() => repo.addCard(any()));
    await c.close();
  });

  test('closing wipes the CVV', () async {
    final c = build()..cvvChanged('123');
    await c.close();
    expect(c.state.cvvLength, 3, reason: 'state is frozen at close');
  });
}
