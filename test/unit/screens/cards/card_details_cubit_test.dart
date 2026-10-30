import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/screens/cards/details/card_details_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements ICardRepository {}

void main() {
  late MockCardRepository repo;
  late CardBloc cards;

  const card = PaymentCard(
    id: 'c1',
    cardNumber: '**** **** **** 1111',
    cardHolderName: 'A',
    expireDate: '12/28',
    cvv: '',
    cardType: CardType.visa,
    balance: Money.zero,
  );

  setUp(() async {
    Logger.sink = (_) {};
    repo = MockCardRepository();
    when(() => repo.getCards()).thenAnswer((_) async => const Success([card]));
    when(
      () => repo.deleteCard('c1'),
    ).thenAnswer((_) async => const Success(null));
    cards = CardBloc(repository: repo, maskSensitive: true)
      ..add(const LoadCardsEvent());
    await cards.stream.firstWhere((s) => s is CardContent);
  });

  tearDown(() => cards.close());

  CardDetailsCubit build() => CardDetailsCubit(cards: cards, cardId: 'c1');

  blocTest<CardDetailsCubit, CardDetailsState>(
    'freeze, flip, unflip and copy bookkeeping',
    build: build,
    act: (c) => c
      ..setFrozen(frozen: true)
      ..setFrozen(frozen: true)
      ..toggleFlip()
      ..unflip()
      ..unflip()
      ..copiedLast4(),
    expect: () => const [
      CardDetailsState(frozen: true),
      CardDetailsState(frozen: true, flipped: true),
      CardDetailsState(frozen: true),
      CardDetailsState(frozen: true, copies: 1),
    ],
  );

  blocTest<CardDetailsCubit, CardDetailsState>(
    'remove deletes through the bloc and reports removed',
    build: build,
    act: (c) => c.remove(),
    expect: () => const [
      CardDetailsState(removal: CardRemoveStatus.removing),
      CardDetailsState(removal: CardRemoveStatus.removed),
    ],
    verify: (_) {
      verify(() => repo.deleteCard('c1')).called(1);
      expect(cards.state, const CardEmpty());
    },
  );

  test('100 concurrent removes delete once', () async {
    final c = build();
    await Future.wait([for (var i = 0; i < 100; i++) c.remove()]);
    verify(() => repo.deleteCard('c1')).called(1);
    expect(c.state.removal, CardRemoveStatus.removed);
    await c.remove();
    verifyNever(() => repo.deleteCard('c1'));
    await c.close();
  });

  blocTest<CardDetailsCubit, CardDetailsState>(
    'a failed delete is reported with the message',
    build: () {
      when(
        () => repo.deleteCard('c1'),
      ).thenAnswer((_) async => const Failure('db locked'));
      return build();
    },
    act: (c) => c.remove(),
    expect: () => const [
      CardDetailsState(removal: CardRemoveStatus.removing),
      CardDetailsState(removal: CardRemoveStatus.failed, message: 'db locked'),
    ],
  );

  test('a bloc that never answers times out', () async {
    final silent = CardBloc(repository: repo);
    await silent.close();
    final c = CardDetailsCubit(
      cards: silent,
      cardId: 'c1',
      timeout: const Duration(milliseconds: 50),
    );
    await c.remove();
    expect(c.state.removal, CardRemoveStatus.failed);
    expect(c.state.message, contains('Could not remove'));
    unawaited(c.close());
  });
}
