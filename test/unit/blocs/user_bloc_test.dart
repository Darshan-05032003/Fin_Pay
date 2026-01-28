import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/blocs/user/user_state.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:fin_pay/domain/usecases/get_user_usecase.dart';
import 'package:fin_pay/domain/usecases/update_user_usecase.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetUserUseCase extends Mock implements GetUserUseCase {}
class MockUpdateUserUseCase extends Mock implements UpdateUserUseCase {}
class MockAuthenticateUserUseCase extends Mock implements AuthenticateUserUseCase {}

void main() {
  late UserBloc userBloc;
  late MockGetUserUseCase mockGetUserUseCase;
  late MockUpdateUserUseCase mockUpdateUserUseCase;
  late MockAuthenticateUserUseCase mockAuthenticateUserUseCase;

  setUp(() {
    mockGetUserUseCase = MockGetUserUseCase();
    mockUpdateUserUseCase = MockUpdateUserUseCase();
    mockAuthenticateUserUseCase = MockAuthenticateUserUseCase();

    userBloc = UserBloc(
      getUserUseCase: mockGetUserUseCase,
      updateUserUseCase: mockUpdateUserUseCase,
      authenticateUserUseCase: mockAuthenticateUserUseCase,
    );
  });

  tearDown(() {
    userBloc.close();
  });

  final tUser = User(
    id: '1',
    fullName: 'Test User',
    email: 'test@example.com',
    password: 'password',
    createdAt: DateTime.now(),
  );

  group('UserBloc', () {
    test('initial state is UserInitial', () {
      expect(userBloc.state, const UserInitial());
    });

    blocTest<UserBloc, UserState>(
      'emits [UserLoading, UserLoaded] when LoadUserEvent is added and user exists',
      build: () {
        when(() => mockGetUserUseCase()).thenAnswer((_) async => Success(tUser));
        return userBloc;
      },
      act: (bloc) => bloc.add(const LoadUserEvent()),
      expect: () => [
        const UserLoading(),
        UserLoaded(tUser),
      ],
    );

    blocTest<UserBloc, UserState>(
      'emits [UserLoading, UserError] when LoadUserEvent fails',
      build: () {
        when(() => mockGetUserUseCase())
            .thenAnswer((_) async => const Failure('Error loading user'));
        return userBloc;
      },
      act: (bloc) => bloc.add(const LoadUserEvent()),
      expect: () => [
        const UserLoading(),
        const UserError('Error loading user'),
      ],
    );

    blocTest<UserBloc, UserState>(
      'emits [UserLoaded] when LogoutEvent is added',
      build: () => userBloc,
      act: (bloc) => bloc.add(const LogoutEvent()),
      expect: () => [
        const UserLoaded(null),
      ],
    );
  });
}
