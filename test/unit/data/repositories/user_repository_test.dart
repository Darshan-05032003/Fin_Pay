import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/data/repositories/user_repository_impl.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDataSource extends Mock implements LocalDataSource {}

void main() {
  late UserRepositoryImpl repository;
  late MockLocalDataSource mockLocalDataSource;

  final tUser = User(
    id: '1',
    fullName: 'Test User',
    email: 'test@example.com',
    createdAt: DateTime.utc(2026),
    balance: const Money.paise(10000),
  );

  setUpAll(() => registerFallbackValue(tUser));

  setUp(() {
    mockLocalDataSource = MockLocalDataSource();
    repository = UserRepositoryImpl(mockLocalDataSource);
  });

  group('UserRepositoryImpl', () {
    test('getCurrentUser should return user from local data source', () async {
      when(
        () => mockLocalDataSource.getUser(),
      ).thenAnswer((_) async => Success(tUser));

      final result = await repository.getCurrentUser();

      expect(result.isSuccess, true);
      expect(result.dataOrNull, tUser);
      verify(() => mockLocalDataSource.getUser()).called(1);
    });

    test('saveUser should call saveUser on local data source', () async {
      when(
        () => mockLocalDataSource.saveUser(tUser),
      ).thenAnswer((_) async => const Success(null));

      final result = await repository.saveUser(tUser);

      expect(result.isSuccess, true);
      verify(() => mockLocalDataSource.saveUser(tUser)).called(1);
    });

    test('updateUser should call updateUser on local data source', () async {
      when(
        () => mockLocalDataSource.updateUser(tUser),
      ).thenAnswer((_) async => const Success(null));

      final result = await repository.updateUser(tUser);

      expect(result.isSuccess, true);
      verify(() => mockLocalDataSource.updateUser(tUser)).called(1);
    });

    test('deleteUser delegates', () async {
      when(
        () => mockLocalDataSource.deleteUser(),
      ).thenAnswer((_) async => const Success(null));
      expect((await repository.deleteUser()).isSuccess, true);
    });

    test(
      'updateBalance rewrites the user with the new Money balance',
      () async {
        when(
          () => mockLocalDataSource.getUser(),
        ).thenAnswer((_) async => Success(tUser));
        when(
          () => mockLocalDataSource.updateUser(any()),
        ).thenAnswer((_) async => const Success(null));

        final result = await repository.updateBalance(const Money.paise(42));

        expect(result.isSuccess, true);
        final saved = verify(
          () => mockLocalDataSource.updateUser(captureAny()),
        ).captured;
        expect((saved.single as User).balance, const Money.paise(42));
      },
    );

    test('updateBalance fails when there is no user', () async {
      when(
        () => mockLocalDataSource.getUser(),
      ).thenAnswer((_) async => const Success(null));
      final result = await repository.updateBalance(Money.zero);
      expect(result.errorOrNull, 'No user found');
      verifyNever(() => mockLocalDataSource.updateUser(any()));
    });

    test('updateBalance propagates a read failure', () async {
      when(
        () => mockLocalDataSource.getUser(),
      ).thenAnswer((_) async => const Failure('db'));
      expect((await repository.updateBalance(Money.zero)).errorOrNull, 'db');
    });
  });
}
