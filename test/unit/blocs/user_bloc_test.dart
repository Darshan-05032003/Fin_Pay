import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/blocs/user/user_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/usecases/get_user_usecase.dart';
import 'package:fin_pay/domain/usecases/update_user_usecase.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetUserUseCase extends Mock implements GetUserUseCase {}

class MockUpdateUserUseCase extends Mock implements UpdateUserUseCase {}

void main() {
  late MockGetUserUseCase getUser;
  late MockUpdateUserUseCase updateUser;
  late List<UserEffect> effects;

  final tUser = User(
    id: '1',
    fullName: 'Test User',
    email: 'test@example.com',
    createdAt: DateTime.utc(2026),
    balance: const Money.paise(1000),
  );

  setUpAll(() => registerFallbackValue(tUser));

  setUp(() {
    Logger.sink = (_) {};
    getUser = MockGetUserUseCase();
    updateUser = MockUpdateUserUseCase();
    effects = [];
  });

  UserBloc build() {
    final bloc = UserBloc(
      getUserUseCase: getUser,
      updateUserUseCase: updateUser,
    );
    bloc.effects.listen(effects.add);
    return bloc;
  }

  test('initial state is UserInitial', () async {
    final bloc = build();
    expect(bloc.state, const UserInitial());
    expect(bloc.state.user, isNull);
    await bloc.close();
  });

  blocTest<UserBloc, UserState>(
    'load: content when a user exists',
    build: () {
      when(() => getUser()).thenAnswer((_) async => Success(tUser));
      return build();
    },
    act: (b) => b.add(const LoadUserEvent()),
    expect: () => [const UserLoading(), UserContent(tUser)],
    verify: (b) {
      final content = b.state as UserContent;
      expect(content.balance, const Money.paise(1000));
      expect(content.userName, 'Test User');
      expect(content.user, tUser);
    },
  );

  blocTest<UserBloc, UserState>(
    'load: empty when no user row exists',
    build: () {
      when(() => getUser()).thenAnswer((_) async => const Success(null));
      return build();
    },
    act: (b) => b.add(const LoadUserEvent()),
    expect: () => [const UserLoading(), const UserEmpty()],
  );

  blocTest<UserBloc, UserState>(
    'load: error when the use case fails',
    build: () {
      when(() => getUser()).thenAnswer((_) async => const Failure('db down'));
      return build();
    },
    act: (b) => b.add(const LoadUserEvent()),
    expect: () => [const UserLoading(), const UserError('db down')],
  );

  blocTest<UserBloc, UserState>(
    'update: emits content and a UserUpdated effect',
    build: () {
      when(
        () => updateUser(any()),
      ).thenAnswer((_) async => const Success(null));
      return build();
    },
    act: (b) => b.add(UpdateUserEvent(tUser.copyWith(fullName: 'New'))),
    expect: () => [UserContent(tUser.copyWith(fullName: 'New'))],
    verify: (_) => expect(effects, [const UserUpdated()]),
  );

  blocTest<UserBloc, UserState>(
    'update: keeps the state and reports failure as an effect',
    build: () {
      when(() => getUser()).thenAnswer((_) async => Success(tUser));
      when(
        () => updateUser(any()),
      ).thenAnswer((_) async => const Failure('ro'));
      return build();
    },
    act: (b) => b
      ..add(const LoadUserEvent())
      ..add(UpdateUserEvent(tUser.copyWith(fullName: 'New'))),
    expect: () => [const UserLoading(), UserContent(tUser)],
    verify: (_) => expect(effects, [const UserUpdateFailed('ro')]),
  );

  blocTest<UserBloc, UserState>(
    'update balance: rewrites the loaded user with the new Money',
    build: () {
      when(() => getUser()).thenAnswer((_) async => Success(tUser));
      when(
        () => updateUser(any()),
      ).thenAnswer((_) async => const Success(null));
      return build();
    },
    act: (b) => b
      ..add(const LoadUserEvent())
      ..add(const UpdateBalanceEvent(Money.paise(42))),
    expect: () => [
      const UserLoading(),
      UserContent(tUser),
      UserContent(tUser.copyWith(balance: const Money.paise(42))),
    ],
  );

  blocTest<UserBloc, UserState>(
    'update balance without a loaded user is an effect, not a crash',
    build: build,
    act: (b) => b.add(const UpdateBalanceEvent(Money.zero)),
    expect: () => const <UserState>[],
    verify: (_) {
      expect(effects, [const UserUpdateFailed('No user loaded')]);
      verifyNever(() => updateUser(any()));
    },
  );

  blocTest<UserBloc, UserState>(
    'clear: goes to empty',
    build: build,
    act: (b) => b.add(const ClearUserEvent()),
    expect: () => [const UserEmpty()],
  );
}
