import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/utils/validators.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where a sign-in attempt is.
enum LoginStatus { idle, submitting, failure, success }

/// Immutable login form state. The password is **not** part of it: the
/// cubit keeps it in a private field so state logs never carry it.
class LoginState extends Equatable {
  const LoginState({
    this.email = '',
    this.emailError,
    this.passwordError,
    this.status = LoginStatus.idle,
    this.failure,
    this.failures = 0,
    this.lockRemaining,
    this.showPassword = false,
    this.submitted = false,
  });

  final String email;
  final String? emailError;
  final String? passwordError;
  final LoginStatus status;

  /// The typed failure of the last attempt, for inline messaging.
  final AuthFailure? failure;

  /// Count of failed attempts in this session; changes on every failure so
  /// the UI can shake even when the message is identical.
  final int failures;

  /// Time left on an [AccountLocked] failure, counted down live.
  final Duration? lockRemaining;
  final bool showPassword;

  /// True after the first submit; validation is live from then on.
  final bool submitted;

  bool get isLocked => lockRemaining != null && lockRemaining! > Duration.zero;

  bool get canSubmit => status != LoginStatus.submitting && !isLocked;

  /// Inline message for the last failure (with the live lock countdown).
  String? get message {
    final f = failure;
    if (f == null) return null;
    if (f is AccountLocked) {
      final remaining = lockRemaining ?? f.remaining;
      return AccountLocked(until: f.until, remaining: remaining).message;
    }
    return f.message;
  }

  LoginState copyWith({
    String? email,
    Object? emailError = _keep,
    Object? passwordError = _keep,
    LoginStatus? status,
    Object? failure = _keep,
    int? failures,
    Object? lockRemaining = _keep,
    bool? showPassword,
    bool? submitted,
  }) => LoginState(
    email: email ?? this.email,
    emailError: emailError == _keep ? this.emailError : emailError as String?,
    passwordError: passwordError == _keep
        ? this.passwordError
        : passwordError as String?,
    status: status ?? this.status,
    failure: failure == _keep ? this.failure : failure as AuthFailure?,
    failures: failures ?? this.failures,
    lockRemaining: lockRemaining == _keep
        ? this.lockRemaining
        : lockRemaining as Duration?,
    showPassword: showPassword ?? this.showPassword,
    submitted: submitted ?? this.submitted,
  );

  static const Object _keep = Object();

  @override
  List<Object?> get props => [
    email,
    emailError,
    passwordError,
    status,
    failure,
    failures,
    lockRemaining,
    showPassword,
    submitted,
  ];
}

/// The login form: validation, submission through [SessionCubit], typed
/// failures and a live lockout countdown on an injectable [Clock].
class LoginCubit extends Cubit<LoginState> {
  LoginCubit({
    required SessionCubit session,
    Clock? clock,
    this.tick = const Duration(seconds: 1),
  }) : _session = session,
       _clock = clock ?? const Clock(),
       super(const LoginState());

  final SessionCubit _session;
  final Clock _clock;

  /// Lock countdown resolution.
  final Duration tick;

  String _passphrase = '';
  Timer? _lockTimer;
  DateTime? _lockDeadline;
  Duration _lockLength = Duration.zero;

  void emailChanged(String value) {
    emit(
      state.copyWith(
        email: value,
        emailError: state.submitted ? Validators.validateEmail(value) : null,
      ),
    );
  }

  void passwordChanged(String value) {
    _passphrase = value;
    if (!state.submitted) return;
    emit(state.copyWith(passwordError: Validators.validatePassword(value)));
  }

  void togglePasswordVisibility() =>
      emit(state.copyWith(showPassword: !state.showPassword));

  /// Re-obscures the password (called when the app goes to the background).
  void hidePassword() {
    if (state.showPassword) emit(state.copyWith(showPassword: false));
  }

  /// Validates, then signs in. Repeated calls while one is in flight, or
  /// while locked, do nothing.
  Future<void> submit() async {
    if (!state.canSubmit) return;
    final emailError = Validators.validateEmail(state.email);
    final passwordError = Validators.validatePassword(_passphrase);
    if (emailError != null || passwordError != null) {
      emit(
        state.copyWith(
          submitted: true,
          emailError: emailError,
          passwordError: passwordError,
          status: LoginStatus.idle,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        submitted: true,
        emailError: null,
        passwordError: null,
        status: LoginStatus.submitting,
        failure: null,
      ),
    );
    await _session.signIn(state.email, _passphrase);
    if (isClosed) return;
    switch (_session.state) {
      case SessionAuthenticated():
        _passphrase = '';
        emit(state.copyWith(status: LoginStatus.success));
      case SessionUnauthenticated(:final failure):
        _fail(failure ?? const InvalidCredentials(remainingAttempts: -1));
      case SessionUnknown() || SessionAuthenticating():
        _fail(const CredentialStoreUnavailable('session unavailable'));
    }
  }

  void _fail(AuthFailure failure) {
    Duration? lock;
    if (failure is AccountLocked) {
      lock = _clamp(failure.remaining, _maxLock);
      _lockLength = lock;
      _lockDeadline = _clock.now().add(lock);
      _lockTimer?.cancel();
      _lockTimer = Timer.periodic(tick, (_) => _tickLock());
    }
    emit(
      state.copyWith(
        status: LoginStatus.failure,
        failure: failure,
        failures: state.failures + 1,
        lockRemaining: lock,
      ),
    );
  }

  static Duration _clamp(Duration d, Duration max) => d < Duration.zero
      ? Duration.zero
      : d > max
      ? max
      : d;

  /// Longest lock the UI will count down (the repository locks for 30 s;
  /// anything larger means a corrupt record or a clock jump).
  static const Duration _maxLock = Duration(minutes: 5);

  void _tickLock() {
    final deadline = _lockDeadline;
    if (deadline == null) return;
    // A clock jump backwards cannot extend the lock beyond its original
    // length; a jump forward ends it.
    final remaining = _clamp(deadline.difference(_clock.now()), _lockLength);
    if (remaining == Duration.zero) {
      _lockTimer?.cancel();
      _lockTimer = null;
      _lockDeadline = null;
      emit(
        state.copyWith(
          lockRemaining: null,
          failure: null,
          status: LoginStatus.idle,
        ),
      );
      return;
    }
    if (remaining != state.lockRemaining) {
      emit(state.copyWith(lockRemaining: remaining));
    }
  }

  @override
  Future<void> close() {
    _lockTimer?.cancel();
    _passphrase = '';
    return super.close();
  }
}
