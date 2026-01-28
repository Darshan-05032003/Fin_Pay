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

  setUp(() {
    mockLocalDataSource = MockLocalDataSource();
    repository = UserRepositoryImpl(mockLocalDataSource);
  });

  group('UserRepositoryImpl', () {
    final tUser = User(
      id: '1',
      fullName: 'Test User',
      email: 'test@example.com',
      password: 'password',
      createdAt: DateTime.now(),
      balance: 100.0,
    );

    test('getCurrentUser should return user from local data source', () async {
      // Arrange
      when(() => mockLocalDataSource.getUser())
          .thenAnswer((_) async => Success(tUser));

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result.isSuccess, true);
      result.onSuccess((user) {
        expect(user, tUser);
      });
      verify(() => mockLocalDataSource.getUser()).called(1);
    });

    test('saveUser should call saveUser on local data source', () async {
      // Arrange
      when(() => mockLocalDataSource.saveUser(tUser))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await repository.saveUser(tUser);

      // Assert
      expect(result.isSuccess, true);
      verify(() => mockLocalDataSource.saveUser(tUser)).called(1);
    });

    test('updateUser should call updateUser on local data source', () async {
      // Arrange
      when(() => mockLocalDataSource.updateUser(tUser))
          .thenAnswer((_) async => const Success(null));

      // Act
      final result = await repository.updateUser(tUser);

      // Assert
      expect(result.isSuccess, true);
      verify(() => mockLocalDataSource.updateUser(tUser)).called(1);
    });
  });
}
