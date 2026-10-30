import 'dart:async';

import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Owns the sign-in session: restores it at start, signs in and out.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required AuthenticateUserUseCase authenticate,
    required AuthRepository authRepository,
  }) : _authenticate = authenticate,
       _authRepository = authRepository,
       super(const SessionUnknown());

  final AuthenticateUserUseCase _authenticate;
  final AuthRepository _authRepository;
  final StreamController<SessionEffect> _effects = StreamController.broadcast();

  /// One-off effects (sign-in failed, signed out…) for the UI.
  Stream<SessionEffect> get effects => _effects.stream;

  bool get isAuthenticated => state is SessionAuthenticated;

  /// Reads the persisted session. Called once before the router is built.
  Future<void> restore() async {
    final userId = await _authRepository.restoreSession();
    emit(
      userId == null
          ? const SessionUnauthenticated()
          : SessionAuthenticated(userId),
    );
  }

  /// Verifies the credentials; a second call while one is in flight is
  /// ignored (double-tap guard).
  Future<void> signIn(String email, String password) async {
    if (state is SessionAuthenticating) return;
    emit(const SessionAuthenticating());
    final result = await _authenticate(email, password);
    if (isClosed) return;
    switch (result) {
      case AuthSuccess(:final user):
        emit(SessionAuthenticated(user.id));
        _effects.add(SignedIn(user));
        Logger.info('Signed in as ${user.id}');
      case AuthFailed(:final failure):
        emit(SessionUnauthenticated(failure: failure));
        _effects.add(SignInFailed(failure));
        Logger.warning('Sign-in failed: ${failure.runtimeType}');
    }
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    if (isClosed) return;
    emit(const SessionUnauthenticated());
    _effects.add(const SignedOut());
  }

  @override
  Future<void> close() async {
    await _effects.close();
    await super.close();
  }
}
