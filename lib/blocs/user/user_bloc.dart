import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/blocs/user/user_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:fin_pay/domain/usecases/get_user_usecase.dart';
import 'package:fin_pay/domain/usecases/update_user_usecase.dart';
import 'package:fin_pay/services/user_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// BLoC for managing user state
/// 
/// This BLoC handles all user-related operations including:
/// - Loading user data
/// - Updating user information
/// - Authentication (login)
/// - Logout
/// - Balance updates
class UserBloc extends Bloc<UserEvent, UserState> {

  UserBloc({
    required GetUserUseCase getUserUseCase,
    required UpdateUserUseCase updateUserUseCase,
    required AuthenticateUserUseCase authenticateUserUseCase,
  })  : _getUserUseCase = getUserUseCase,
        _updateUserUseCase = updateUserUseCase,
        _authenticateUserUseCase = authenticateUserUseCase,
        super(const UserInitial()) {
    on<LoadUserEvent>(_onLoadUser);
    on<UpdateUserEvent>(_onUpdateUser);
    on<UpdateBalanceEvent>(_onUpdateBalance);
    on<LoginEvent>(_onLogin);
    on<LogoutEvent>(_onLogout);
  }
  final GetUserUseCase _getUserUseCase;
  final UpdateUserUseCase _updateUserUseCase;
  final AuthenticateUserUseCase _authenticateUserUseCase;

  /// Handle loading user data
  Future<void> _onLoadUser(
    LoadUserEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(const UserLoading());

    try {
      final result = await _getUserUseCase();

      result.onSuccess((user) async {
        if (user == null) {
          // Initialize default user if none exists
          await UserService.init();
          final retryResult = await _getUserUseCase();
          retryResult.onSuccess((retryUser) {
            emit(UserLoaded(retryUser));
            Logger.info('User loaded: ${retryUser?.email ?? 'null'}');
          }).onFailure((message, error) {
            emit(UserError(message));
            Logger.error('Failed to load user: $message', error);
          });
        } else {
          emit(UserLoaded(user));
          Logger.info('User loaded: ${user.email}');
        }
      }).onFailure((message, error) {
        emit(UserError(message));
        Logger.error('Failed to load user: $message', error);
      });
    } catch (e) {
      emit(UserError('Unexpected error: $e'));
      Logger.error('Unexpected error loading user', e);
    }
  }

  /// Handle updating user information
  Future<void> _onUpdateUser(
    UpdateUserEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(const UserLoading());

    try {
      final result = await _updateUserUseCase(event.user);

      result
          .onSuccess((_) {
            emit(UserLoaded(event.user));
            Logger.info('User updated successfully');
          })
          .onFailure((message, error) {
            emit(UserError(message));
            Logger.error('Failed to update user: $message', error);
          });
    } catch (e) {
      emit(UserError('Unexpected error: $e'));
      Logger.error('Unexpected error updating user', e);
    }
  }

  /// Handle updating user balance
  Future<void> _onUpdateBalance(
    UpdateBalanceEvent event,
    Emitter<UserState> emit,
  ) async {
    final currentState = state;
    if (currentState is UserLoaded && currentState.user != null) {
      final updatedUser = currentState.user!.copyWith(balance: event.newBalance);
      add(UpdateUserEvent(updatedUser));
    }
  }

  /// Handle user authentication (login)
  Future<void> _onLogin(
    LoginEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(const UserLoading());

    try {
      final result = await _authenticateUserUseCase(event.email, event.password);

      result
          .onSuccess((user) {
            emit(UserLoaded(user));
            Logger.info('User authenticated: ${user.email}');
          })
          .onFailure((message, error) {
            emit(UserError(message));
            Logger.error('Authentication failed: $message', error);
          });
    } catch (e) {
      emit(UserError('Unexpected error: $e'));
      Logger.error('Unexpected error during login', e);
    }
  }

  /// Handle user logout
  void _onLogout(
    LogoutEvent event,
    Emitter<UserState> emit,
  ) {
    emit(const UserLoaded(null));
    Logger.info('User logged out');
  }
}
