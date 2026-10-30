import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/usecases/add_transaction_usecase.dart';
import 'package:fin_pay/domain/usecases/get_transactions_usecase.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTransactionRepository extends Mock
    implements ITransactionRepository {}

void main() {
  late MockTransactionRepository repo;
  final tx = Transaction(
    id: 't',
    title: 'Coffee',
    amount: const Money.paise(-100),
    date: DateTime.utc(2026),
    type: TransactionType.payment,
    icon: 'C',
  );

  setUpAll(() => registerFallbackValue(tx));

  setUp(() {
    repo = MockTransactionRepository();
  });

  group('AddTransactionUseCase', () {
    test(
      'rejects a zero amount and a blank title without calling the repo',
      () async {
        final useCase = AddTransactionUseCase(repo);
        expect(
          (await useCase(tx.copyWith(amount: Money.zero))).isFailure,
          true,
        );
        expect((await useCase(tx.copyWith(title: '  '))).isFailure, true);
        verifyNever(() => repo.addTransaction(any()));
      },
    );

    test('forwards the outcome from the repository', () async {
      when(
        () => repo.addTransaction(tx),
      ).thenAnswer((_) async => const Success(TransactionOutcome.duplicate));
      final result = await AddTransactionUseCase(repo)(tx);
      expect(result.dataOrNull, TransactionOutcome.duplicate);
    });

    test('forwards failures', () async {
      when(
        () => repo.addTransaction(tx),
      ).thenAnswer((_) async => const Failure('boom'));
      expect((await AddTransactionUseCase(repo)(tx)).errorOrNull, 'boom');
    });
  });

  group('GetTransactionsUseCase', () {
    test('passes limit and offset', () async {
      when(
        () => repo.getTransactions(limit: 2, offset: 4),
      ).thenAnswer((_) async => Success([tx]));
      final result = await GetTransactionsUseCase(repo)(limit: 2, offset: 4);
      expect(result.dataOrNull, [tx]);
    });
  });
}
