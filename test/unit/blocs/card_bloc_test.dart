import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements ICardRepository {}

void main() {
  late MockCardRepository repo;
  late List<CardEffect> effects;

  const card = PaymentCard(
    id: 'c1',
    cardNumber: '4111 1111 1111 1111',
    cardHolderName: 'J',
    expireDate: '12/28',
    cvv: '123',
    cardType: CardType.visa,
    balance: Money.paise(100),
  );
  final other = card.copyWith(id: 'c2');

  setUpAll(() => registerFallbackValue(card));

  setUp(() {
    Logger.sink = (_) {};
    repo = MockCardRepository();
    effects = [];
    when(() => repo.getCards()).thenAnswer((_) async => Success([card, other]));
  });

  CardBloc build() {
    final bloc = CardBloc(repository: repo);
    bloc.effects.listen(effects.add);
    return bloc;
  }

  test('initial state', () async {
    final bloc = build();
    expect(bloc.state, const CardInitial());
    await bloc.close();
  });

  blocTest<CardBloc, CardState>(
    'load content',
    build: build,
    act: (b) => b.add(const LoadCardsEvent()),
    expect: () => [
      const CardLoading(),
      CardContent([card, other]),
    ],
  );

  blocTest<CardBloc, CardState>(
    'maskSensitive: loaded cards carry the mask and no CVV',
    build: () {
      final bloc = CardBloc(repository: repo, maskSensitive: true);
      bloc.effects.listen(effects.add);
      return bloc;
    },
    act: (b) => b.add(const LoadCardsEvent()),
    expect: () => [
      const CardLoading(),
      CardContent([
        card.copyWith(cardNumber: '**** **** **** 1111', cvv: ''),
        other.copyWith(cardNumber: '**** **** **** 1111', cvv: ''),
      ]),
    ],
    verify: (b) {
      final content = b.state as CardContent;
      expect(content.toString(), isNot(contains('4111 1111 1111 1111')));
      expect(content.toString(), isNot(contains('123')));
      expect(content.cards.every((c) => c.last4 == '1111'), isTrue);
    },
  );

  blocTest<CardBloc, CardState>(
    'maskSensitive: the CardAdded effect is sanitised too',
    build: () {
      when(
        () => repo.addCard(any()),
      ).thenAnswer((_) async => const Success(null));
      final bloc = CardBloc(repository: repo, maskSensitive: true);
      bloc.effects.listen(effects.add);
      return bloc;
    },
    act: (b) => b.add(const AddCardEvent(card)),
    verify: (_) {
      final added = effects.whereType<CardAdded>().single;
      expect(added.card.cvv, isEmpty);
      expect(added.card.cardNumber, '**** **** **** 1111');
    },
  );

  blocTest<CardBloc, CardState>(
    'load empty',
    build: () {
      when(() => repo.getCards()).thenAnswer((_) async => const Success([]));
      return build();
    },
    act: (b) => b.add(const LoadCardsEvent()),
    expect: () => [const CardLoading(), const CardEmpty()],
  );

  blocTest<CardBloc, CardState>(
    'load error',
    build: () {
      when(() => repo.getCards()).thenAnswer((_) async => const Failure('db'));
      return build();
    },
    act: (b) => b.add(const LoadCardsEvent()),
    expect: () => [const CardLoading(), const CardError('db')],
  );

  blocTest<CardBloc, CardState>(
    'add: effect then reload',
    build: () {
      when(
        () => repo.addCard(card),
      ).thenAnswer((_) async => const Success(null));
      return build();
    },
    act: (b) => b.add(const AddCardEvent(card)),
    expect: () => [
      const CardLoading(),
      CardContent([card, other]),
    ],
    verify: (_) => expect(effects, [const CardAdded(card)]),
  );

  blocTest<CardBloc, CardState>(
    'add failure is an effect only',
    build: () {
      when(
        () => repo.addCard(card),
      ).thenAnswer((_) async => const Failure('vault'));
      return build();
    },
    act: (b) => b.add(const AddCardEvent(card)),
    expect: () => const <CardState>[],
    verify: (_) => expect(effects, [const CardFailed('vault')]),
  );

  blocTest<CardBloc, CardState>(
    'delete removes from content; last one yields empty',
    build: () {
      when(
        () => repo.deleteCard(any()),
      ).thenAnswer((_) async => const Success(null));
      return build();
    },
    act: (b) => b
      ..add(const LoadCardsEvent())
      ..add(const DeleteCardEvent('c1'))
      ..add(const DeleteCardEvent('c2')),
    expect: () => [
      const CardLoading(),
      CardContent([card, other]),
      CardContent([other]),
      const CardEmpty(),
    ],
    verify: (_) =>
        expect(effects, [const CardDeleted('c1'), const CardDeleted('c2')]),
  );

  blocTest<CardBloc, CardState>(
    'delete failure is an effect',
    build: () {
      when(
        () => repo.deleteCard('c1'),
      ).thenAnswer((_) async => const Failure('x'));
      return build();
    },
    act: (b) => b.add(const DeleteCardEvent('c1')),
    expect: () => const <CardState>[],
    verify: (_) => expect(effects, [const CardFailed('x')]),
  );
}
