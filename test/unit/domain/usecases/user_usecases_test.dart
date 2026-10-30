import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/domain/usecases/get_user_usecase.dart';
import 'package:fin_pay/domain/usecases/update_user_usecase.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepository extends Mock implements IUserRepository {}

void main() {
  late MockUserRepository repo;
  final user = User(
    id: 'u',
    fullName: 'U',
    email: 'u@x.com',
    createdAt: DateTime.utc(2026),
  );

  setUp(() => repo = MockUserRepository());

  test('GetUserUseCase returns the repository result', () async {
    when(() => repo.getCurrentUser()).thenAnswer((_) async => Success(user));
    expect((await GetUserUseCase(repo)()).dataOrNull, user);
    when(
      () => repo.getCurrentUser(),
    ).thenAnswer((_) async => const Failure('db'));
    expect((await GetUserUseCase(repo)()).errorOrNull, 'db');
  });

  test('UpdateUserUseCase forwards the user', () async {
    when(
      () => repo.updateUser(user),
    ).thenAnswer((_) async => const Success(null));
    expect((await UpdateUserUseCase(repo)(user)).isSuccess, isTrue);
    verify(() => repo.updateUser(user)).called(1);
  });

  group('Result helpers', () {
    test('map, flatMap, onSuccess and onFailure', () async {
      const ok = Success<int>(2);
      const bad = Failure<int>('no', 'cause');
      expect(ok.map((v) => v * 2).dataOrNull, 4);
      expect(bad.map((v) => v * 2).errorOrNull, 'no');
      expect(ok.flatMap((v) => Success('$v')).dataOrNull, '2');
      expect(bad.flatMap((v) => Success('$v')).isFailure, isTrue);
      expect((await bad.flatMapAsync((v) async => Success(v))).isFailure, true);
      var seen = 0;
      ok.onSuccess((v) => seen = v).onFailure((_, _) => seen = -1);
      expect(seen, 2);
      Object? cause;
      bad.onFailure((_, e) => cause = e).onSuccess((_) => cause = null);
      expect(cause, 'cause');
    });
  });
}
