import 'dart:convert';

import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/fakes/fake_secure_storage.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/data/repositories/card_repository_impl.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDataSource extends Mock implements LocalDataSource {}

void main() {
  late MockLocalDataSource ds;
  late FakeSecureStorage storage;
  late CardRepositoryImpl repo;

  const card = PaymentCard(
    id: 'c1',
    cardNumber: '4111 1111 1111 1234',
    cardHolderName: 'J',
    expireDate: '12/28',
    cvv: '987',
    cardType: CardType.visa,
    balance: Money.paise(1),
  );
  final masked = card.copyWith(cardNumber: card.maskedNumber, cvv: '');

  setUpAll(() => registerFallbackValue(card));

  setUp(() {
    ds = MockLocalDataSource();
    storage = FakeSecureStorage();
    repo = CardRepositoryImpl(ds, storage);
    when(() => ds.saveCard(any())).thenAnswer((_) async => const Success(null));
    when(
      () => ds.deleteCard(any()),
    ).thenAnswer((_) async => const Success(null));
    when(() => ds.getCards()).thenAnswer((_) async => Success([masked]));
  });

  test(
    'addCard puts PAN and CVV in secure storage and the row in the db',
    () async {
      expect((await repo.addCard(card)).isSuccess, isTrue);
      final secret = jsonDecode(storage.values['card:c1']!) as Map;
      expect(secret['cardNumber'], '4111 1111 1111 1234');
      expect(secret['cvv'], '987');
      verify(() => ds.saveCard(card)).called(1);
    },
  );

  test('getCards re-attaches the secrets', () async {
    await repo.addCard(card);
    final cards = (await repo.getCards()).dataOrNull!;
    expect(cards.single, card);
    expect(cards.single.hasFullDetails, isTrue);
  });

  test(
    'getCards returns masked cards when secrets are missing or broken',
    () async {
      expect((await repo.getCards()).dataOrNull!.single, masked);
      storage.values['card:c1'] = 'not json';
      expect((await repo.getCards()).dataOrNull!.single, masked);
      storage.failing = true;
      expect((await repo.getCards()).dataOrNull!.single, masked);
    },
  );

  test(
    'readCvv returns only the CVV from the vault, null when absent',
    () async {
      await repo.addCard(card);
      expect((await repo.readCvv('c1')).dataOrNull, '987');
      expect((await repo.readCvv('nope')).dataOrNull, isNull);
      storage.values['card:c1'] = 'not json';
      expect((await repo.readCvv('c1')).isFailure, isTrue);
      storage.failing = true;
      expect((await repo.readCvv('c1')).isFailure, isTrue);
    },
  );

  test('getCards propagates a db failure', () async {
    when(() => ds.getCards()).thenAnswer((_) async => const Failure('db'));
    expect((await repo.getCards()).errorOrNull, 'db');
  });

  test(
    'addCard fails and writes nothing when secure storage is down',
    () async {
      storage.failing = true;
      expect((await repo.addCard(card)).isFailure, isTrue);
      verifyNever(() => ds.saveCard(any()));
    },
  );

  test('addCard removes the secret again when the db write fails', () async {
    when(() => ds.saveCard(any())).thenAnswer((_) async => const Failure('db'));
    expect((await repo.addCard(card)).isFailure, isTrue);
    expect(storage.values.containsKey('card:c1'), isFalse);
  });

  test('deleteCard removes the row and the secret', () async {
    await repo.addCard(card);
    expect((await repo.deleteCard('c1')).isSuccess, isTrue);
    expect(storage.values.containsKey('card:c1'), isFalse);
    verify(() => ds.deleteCard('c1')).called(1);
  });

  test('deleteCard reports a secret that could not be removed', () async {
    await repo.addCard(card);
    storage.failing = true;
    expect((await repo.deleteCard('c1')).isFailure, isTrue);
  });
}
