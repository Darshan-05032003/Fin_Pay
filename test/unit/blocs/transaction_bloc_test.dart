import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_event.dart';
import 'package:fin_pay/blocs/transaction/transaction_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/usecases/add_transaction_usecase.dart';
import 'package:fin_pay/domain/usecases/get_transactions_usecase.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetTransactions extends Mock implements GetTransactionsUseCase {}

class MockAddTransaction extends Mock implements AddTransactionUseCase {}

class MockTransactionRepository extends Mock
    implements ITransactionRepository {}

void main() {
  late MockGetTransactions getTransactions;
  late MockAddTransaction addTransaction;
  late MockTransactionRepository repository;
  late List<TransactionEffect> effects;

  Transaction tx(String id, int paise) => Transaction(
    id: id,
    title: 'Tx $id',
    amount: Money.paise(paise),
    date: DateTime.utc(2026),
    type: paise < 0 ? TransactionType.payment : TransactionType.receiveMoney,
    icon: 'T',
  );
  final list = [tx('a', -100), tx('b', 500), tx('c', -50)];

  setUpAll(() => registerFallbackValue(tx('x', 1)));

  setUp(() {
    Logger.sink = (_) {};
    getTransactions = MockGetTransactions();
    addTransaction = MockAddTransaction();
    repository = MockTransactionRepository();
    effects = [];
    when(
      () => getTransactions(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => Success(list));
  });

  TransactionBloc build() {
    final bloc = TransactionBloc(
      getTransactionsUseCase: getTransactions,
      addTransactionUseCase: addTransaction,
      transactionRepository: repository,
    );
    bloc.effects.listen(effects.add);
    return bloc;
  }

  test('initial state', () async {
    final bloc = build();
    expect(bloc.state, const TransactionInitial());
    expect(bloc.hasEffectListeners, isTrue);
    await bloc.close();
  });

  group('load', () {
    blocTest<TransactionBloc, TransactionState>(
      'content with Money totals',
      build: build,
      act: (b) => b.add(const LoadTransactionsEvent()),
      expect: () => [const TransactionLoading(), TransactionContent(list)],
      verify: (b) {
        final content = b.state as TransactionContent;
        expect(content.totalIncome, const Money.paise(500));
        expect(content.totalExpenses, const Money.paise(150));
        expect(content.recentTransactions, list);
        expect(content.query, isNull);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'empty',
      build: () {
        when(
          () => getTransactions(limit: 3),
        ).thenAnswer((_) async => const Success([]));
        return build();
      },
      act: (b) => b.add(const LoadTransactionsEvent(limit: 3)),
      expect: () => [const TransactionLoading(), const TransactionEmpty()],
    );

    blocTest<TransactionBloc, TransactionState>(
      'error',
      build: () {
        when(
          () => getTransactions(),
        ).thenAnswer((_) async => const Failure('db'));
        return build();
      },
      act: (b) => b.add(const LoadTransactionsEvent()),
      expect: () => [const TransactionLoading(), const TransactionError('db')],
    );
  });

  group('search', () {
    blocTest<TransactionBloc, TransactionState>(
      'content tagged with the query',
      build: () {
        when(
          () => repository.searchTransactions('rent'),
        ).thenAnswer((_) async => Success([list.first]));
        return build();
      },
      act: (b) => b.add(const SearchTransactionsEvent(' rent ')),
      expect: () => [
        const TransactionLoading(),
        TransactionContent([list.first], query: 'rent'),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'empty result keeps the query for the empty state',
      build: () {
        when(
          () => repository.searchTransactions('zzz'),
        ).thenAnswer((_) async => const Success([]));
        return build();
      },
      act: (b) => b.add(const SearchTransactionsEvent('zzz')),
      expect: () => [
        const TransactionLoading(),
        const TransactionEmpty(query: 'zzz'),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'a blank query reloads the full list',
      build: build,
      act: (b) => b.add(const SearchTransactionsEvent('   ')),
      expect: () => [const TransactionLoading(), TransactionContent(list)],
      verify: (_) => verifyNever(() => repository.searchTransactions(any())),
    );

    blocTest<TransactionBloc, TransactionState>(
      'search failure',
      build: () {
        when(
          () => repository.searchTransactions('x'),
        ).thenAnswer((_) async => const Failure('boom'));
        return build();
      },
      act: (b) => b.add(const SearchTransactionsEvent('x')),
      expect: () => [
        const TransactionLoading(),
        const TransactionError('boom'),
      ],
    );
  });

  group('add', () {
    final newTx = tx('n', -10);

    blocTest<TransactionBloc, TransactionState>(
      'recorded: effect then reload with the last limit',
      build: () {
        when(
          () => addTransaction(newTx),
        ).thenAnswer((_) async => const Success(TransactionOutcome.recorded));
        return build();
      },
      act: (b) => b
        ..add(const LoadTransactionsEvent(limit: 5))
        ..add(AddTransactionEvent(newTx)),
      expect: () => [
        const TransactionLoading(),
        TransactionContent(list),
        const TransactionLoading(),
        TransactionContent(list),
      ],
      verify: (_) {
        expect(effects, [TransactionAdded(newTx)]);
        verify(() => getTransactions(limit: 5)).called(2);
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'duplicate: effect only, no reload',
      build: () {
        when(
          () => addTransaction(newTx),
        ).thenAnswer((_) async => const Success(TransactionOutcome.duplicate));
        return build();
      },
      act: (b) => b.add(AddTransactionEvent(newTx)),
      expect: () => const <TransactionState>[],
      verify: (_) {
        expect(effects, [TransactionDuplicate(newTx)]);
        verifyNever(
          () => getTransactions(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        );
      },
    );

    blocTest<TransactionBloc, TransactionState>(
      'insufficient balance and no user are rejections',
      build: () {
        when(() => addTransaction(newTx)).thenAnswer(
          (_) async => const Success(TransactionOutcome.insufficientBalance),
        );
        when(
          () => addTransaction(tx('m', 1)),
        ).thenAnswer((_) async => const Success(TransactionOutcome.noUser));
        return build();
      },
      act: (b) => b
        ..add(AddTransactionEvent(newTx))
        ..add(AddTransactionEvent(tx('m', 1))),
      expect: () => const <TransactionState>[],
      verify: (_) => expect(effects, [
        TransactionRejected(newTx, 'Insufficient balance'),
        TransactionRejected(tx('m', 1), 'No account'),
      ]),
    );

    blocTest<TransactionBloc, TransactionState>(
      'storage failure is an effect and the state is untouched',
      build: () {
        when(
          () => addTransaction(newTx),
        ).thenAnswer((_) async => const Failure('disk'));
        return build();
      },
      act: (b) => b.add(AddTransactionEvent(newTx)),
      expect: () => const <TransactionState>[],
      verify: (_) => expect(effects, [const TransactionFailed('disk')]),
    );

    blocTest<TransactionBloc, TransactionState>(
      'a burst of the same event is processed serially',
      build: () {
        var calls = 0;
        when(() => addTransaction(newTx)).thenAnswer((_) async {
          calls++;
          return Success(
            calls == 1
                ? TransactionOutcome.recorded
                : TransactionOutcome.duplicate,
          );
        });
        return build();
      },
      act: (b) {
        for (var i = 0; i < 5; i++) {
          b.add(AddTransactionEvent(newTx));
        }
      },
      verify: (_) {
        expect(effects.whereType<TransactionAdded>(), hasLength(1));
        expect(effects.whereType<TransactionDuplicate>(), hasLength(4));
      },
    );
  });

  group('delete', () {
    blocTest<TransactionBloc, TransactionState>(
      'removes from content and emits an effect',
      build: () {
        when(
          () => repository.deleteTransaction('a'),
        ).thenAnswer((_) async => const Success(null));
        return build();
      },
      act: (b) => b
        ..add(const LoadTransactionsEvent())
        ..add(const DeleteTransactionEvent('a')),
      expect: () => [
        const TransactionLoading(),
        TransactionContent(list),
        TransactionContent(list.sublist(1)),
      ],
      verify: (_) => expect(effects, [const TransactionDeleted('a')]),
    );

    blocTest<TransactionBloc, TransactionState>(
      'deleting the last item yields empty',
      build: () {
        when(
          () => getTransactions(),
        ).thenAnswer((_) async => Success([list.first]));
        when(
          () => repository.deleteTransaction('a'),
        ).thenAnswer((_) async => const Success(null));
        return build();
      },
      act: (b) => b
        ..add(const LoadTransactionsEvent())
        ..add(const DeleteTransactionEvent('a')),
      expect: () => [
        const TransactionLoading(),
        TransactionContent([list.first]),
        const TransactionEmpty(),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'failure is an effect',
      build: () {
        when(
          () => repository.deleteTransaction('a'),
        ).thenAnswer((_) async => const Failure('locked'));
        return build();
      },
      act: (b) => b.add(const DeleteTransactionEvent('a')),
      expect: () => const <TransactionState>[],
      verify: (_) => expect(effects, [const TransactionFailed('locked')]),
    );
  });

  test('closing the bloc closes the effect stream', () async {
    final bloc = build();
    var done = false;
    bloc.effects.listen(null, onDone: () => done = true);
    await bloc.close();
    expect(done, isTrue);
  });
}
