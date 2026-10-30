import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/data/repositories/notification_repository_impl.dart';
import 'package:fin_pay/data/repositories/transaction_repository_impl.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDataSource extends Mock implements LocalDataSource {}

void main() {
  late MockLocalDataSource ds;
  final tx = Transaction(
    id: 't',
    title: 'T',
    amount: const Money.paise(1),
    date: DateTime.utc(2026),
    type: TransactionType.topUp,
    icon: 'T',
  );
  final note = NotificationItem(
    id: 'n',
    title: 'N',
    message: 'm',
    time: DateTime.utc(2026),
    type: NotificationType.cashback,
  );

  setUpAll(() {
    registerFallbackValue(tx);
    registerFallbackValue(note);
  });

  setUp(() => ds = MockLocalDataSource());

  group('TransactionRepositoryImpl', () {
    late TransactionRepositoryImpl repo;
    setUp(() => repo = TransactionRepositoryImpl(ds));

    test(
      'getTransactions / getRecentTransactions pass paging through',
      () async {
        when(
          () => ds.getTransactions(limit: 5),
        ).thenAnswer((_) async => Success([tx]));
        expect((await repo.getRecentTransactions()).dataOrNull, [tx]);
        when(
          () => ds.getTransactions(limit: 10, offset: 20),
        ).thenAnswer((_) async => const Success([]));
        expect(
          (await repo.getTransactions(limit: 10, offset: 20)).dataOrNull,
          isEmpty,
        );
      },
    );

    test('searchTransactions trims and falls back to the full list for '
        'blank queries', () async {
      when(
        () => ds.searchTransactions('cof'),
      ).thenAnswer((_) async => Success([tx]));
      when(
        () => ds.getTransactions(),
      ).thenAnswer((_) async => const Success([]));
      expect((await repo.searchTransactions('  cof ')).dataOrNull, [tx]);
      expect((await repo.searchTransactions('   ')).dataOrNull, isEmpty);
      verifyNever(() => ds.searchTransactions('   '));
    });

    test(
      'addTransaction, addTransactions and deleteTransaction delegate',
      () async {
        when(
          () => ds.saveTransaction(tx),
        ).thenAnswer((_) async => const Success(TransactionOutcome.recorded));
        when(
          () => ds.saveTransactions([tx]),
        ).thenAnswer((_) async => const Success(null));
        when(
          () => ds.deleteTransaction('t'),
        ).thenAnswer((_) async => const Success(null));
        expect(
          (await repo.addTransaction(tx)).dataOrNull,
          TransactionOutcome.recorded,
        );
        expect((await repo.addTransactions([tx])).isSuccess, isTrue);
        expect((await repo.deleteTransaction('t')).isSuccess, isTrue);
      },
    );
  });

  group('NotificationRepositoryImpl', () {
    late NotificationRepositoryImpl repo;
    setUp(() => repo = NotificationRepositoryImpl(ds));

    test('delegates every call', () async {
      when(
        () => ds.getNotifications(limit: 3),
      ).thenAnswer((_) async => Success([note]));
      when(
        () => ds.saveNotification(note),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => ds.deleteNotification('n'),
      ).thenAnswer((_) async => const Failure('nope'));
      expect((await repo.getNotifications(limit: 3)).dataOrNull, [note]);
      expect((await repo.addNotification(note)).isSuccess, isTrue);
      expect((await repo.deleteNotification('n')).errorOrNull, 'nope');
    });
  });
}
