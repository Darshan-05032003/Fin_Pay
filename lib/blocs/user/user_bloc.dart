import 'dart:async';

import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/blocs/user/user_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/usecases/get_user_usecase.dart';
import 'package:fin_pay/domain/usecases/update_user_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Loads and updates the account holder.
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc({
    required GetUserUseCase getUserUseCase,
    required UpdateUserUseCase updateUserUseCase,
  }) : _getUserUseCase = getUserUseCase,
       _updateUserUseCase = updateUserUseCase,
       super(const UserInitial()) {
    on<LoadUserEvent>(_onLoadUser);
    on<UpdateUserEvent>(_onUpdateUser);
    on<UpdateBalanceEvent>(_onUpdateBalance);
    on<ClearUserEvent>((_, emit) => emit(const UserEmpty()));
  }

  final GetUserUseCase _getUserUseCase;
  final UpdateUserUseCase _updateUserUseCase;
  final StreamController<UserEffect> _effects = StreamController.broadcast();

  /// One-off effects for the UI.
  Stream<UserEffect> get effects => _effects.stream;

  Future<void> _onLoadUser(LoadUserEvent event, Emitter<UserState> emit) async {
    emit(const UserLoading());
    final result = await _getUserUseCase();
    switch (result) {
      case Success(data: final user) when user != null:
        emit(UserContent(user));
      case Success():
        emit(const UserEmpty());
      case Failure(:final message):
        emit(UserError(message));
        Logger.error('Failed to load user: $message');
    }
  }

  Future<void> _onUpdateUser(
    UpdateUserEvent event,
    Emitter<UserState> emit,
  ) async {
    final result = await _updateUserUseCase(event.user);
    switch (result) {
      case Success():
        emit(UserContent(event.user));
        _effects.add(const UserUpdated());
      case Failure(:final message):
        // Keep showing what we had; report the failure as an effect.
        _effects.add(UserUpdateFailed(message));
        Logger.error('Failed to update user: $message');
    }
  }

  Future<void> _onUpdateBalance(
    UpdateBalanceEvent event,
    Emitter<UserState> emit,
  ) async {
    final current = state.user;
    if (current == null) {
      _effects.add(const UserUpdateFailed('No user loaded'));
      return;
    }
    await _onUpdateUser(
      UpdateUserEvent(current.copyWith(balance: event.newBalance)),
      emit,
    );
  }

  @override
  Future<void> close() async {
    await _effects.close();
    await super.close();
  }
}
