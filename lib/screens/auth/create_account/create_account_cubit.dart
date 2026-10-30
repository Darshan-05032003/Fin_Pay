import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/auth/demo_credentials.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/utils/validators.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where the sign-up flow is.
enum CreateAccountStatus {
  /// Filling the form.
  editing,

  /// Form accepted; the OTP step is next.
  pendingVerification,

  /// OTP verified; credentials and the account are being written.
  completing,

  /// Signed in.
  completed,

  /// Writing failed; the user can retry.
  failed,
}

/// Immutable sign-up form state. The password and the OTP are **not** in
/// it: both stay private to the cubit (see `SECURITY_REVIEW.md`, F3).
class CreateAccountState extends Equatable {
  const CreateAccountState({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.nameError,
    this.emailError,
    this.phoneError,
    this.passwordError,
    this.strength = PasswordStrength.none,
    this.status = CreateAccountStatus.editing,
    this.errorMessage,
    this.showPassword = false,
    this.submitted = false,
  });

  final String name;
  final String email;

  /// National 10-digit number once normalised (after a successful submit).
  final String phone;
  final String? nameError;
  final String? emailError;
  final String? phoneError;
  final String? passwordError;
  final PasswordStrength strength;
  final CreateAccountStatus status;
  final String? errorMessage;
  final bool showPassword;
  final bool submitted;

  bool get isBusy => status == CreateAccountStatus.completing;

  /// `+91 ••••• •3210` for the verification screen.
  String get maskedPhone {
    final digits = Validators.normalizePhone(phone);
    if (digits.length < 4) return '';
    return '+91 ••••• •${digits.substring(digits.length - 4)}';
  }

  CreateAccountState copyWith({
    String? name,
    String? email,
    String? phone,
    Object? nameError = _keep,
    Object? emailError = _keep,
    Object? phoneError = _keep,
    Object? passwordError = _keep,
    PasswordStrength? strength,
    CreateAccountStatus? status,
    Object? errorMessage = _keep,
    bool? showPassword,
    bool? submitted,
  }) => CreateAccountState(
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    nameError: nameError == _keep ? this.nameError : nameError as String?,
    emailError: emailError == _keep ? this.emailError : emailError as String?,
    phoneError: phoneError == _keep ? this.phoneError : phoneError as String?,
    passwordError: passwordError == _keep
        ? this.passwordError
        : passwordError as String?,
    strength: strength ?? this.strength,
    status: status ?? this.status,
    errorMessage: errorMessage == _keep
        ? this.errorMessage
        : errorMessage as String?,
    showPassword: showPassword ?? this.showPassword,
    submitted: submitted ?? this.submitted,
  );

  static const Object _keep = Object();

  @override
  List<Object?> get props => [
    name,
    email,
    phone,
    nameError,
    emailError,
    phoneError,
    passwordError,
    strength,
    status,
    errorMessage,
    showPassword,
    submitted,
  ];
}

/// The sign-up flow object shared by the create-account and verification
/// screens (scoped to their shell route). It holds the password in memory
/// only, derives the demo OTP from the phone number, and after verification
/// stores the salted hash, re-keys the on-device account and signs in.
class CreateAccountCubit extends Cubit<CreateAccountState> {
  CreateAccountCubit({
    required AuthRepository auth,
    required IUserRepository users,
    required SessionCubit session,
    Clock? clock,
  }) : _auth = auth,
       _users = users,
       _session = session,
       _clock = clock ?? const Clock(),
       super(const CreateAccountState());

  final AuthRepository _auth;
  final IUserRepository _users;
  final SessionCubit _session;
  final Clock _clock;

  String _passphrase = '';
  bool _completing = false;

  /// The simulated one-time code: the last six digits of the phone number
  /// (D-030). Empty unless verification is pending.
  String get expectedOtp =>
      state.status == CreateAccountStatus.pendingVerification ||
          state.status == CreateAccountStatus.completing ||
          state.status == CreateAccountStatus.failed
      ? otpFor(state.phone)
      : '';

  /// Last six digits of a normalised phone number.
  static String otpFor(String phoneDigits) => phoneDigits.length < 6
      ? phoneDigits
      : phoneDigits.substring(phoneDigits.length - 6);

  void nameChanged(String value) => _edit(
    state.copyWith(
      name: value,
      nameError: state.submitted ? Validators.validateName(value) : null,
    ),
  );

  void emailChanged(String value) => _edit(
    state.copyWith(
      email: value,
      emailError: state.submitted ? Validators.validateEmail(value) : null,
    ),
  );

  void phoneChanged(String value) => _edit(
    state.copyWith(
      phone: value,
      phoneError: state.submitted ? Validators.validatePhone(value) : null,
    ),
  );

  void passwordChanged(String value) {
    _passphrase = value;
    _edit(
      state.copyWith(
        strength: Validators.passwordStrength(value),
        passwordError: state.submitted
            ? Validators.validatePassword(value)
            : null,
      ),
    );
  }

  /// Any edit after submit returns the flow to editing (a new OTP will be
  /// derived from the new phone number).
  void _edit(CreateAccountState next) {
    if (state.isBusy) return;
    emit(
      next.status == CreateAccountStatus.editing
          ? next
          : next.copyWith(
              status: CreateAccountStatus.editing,
              errorMessage: null,
            ),
    );
  }

  void togglePasswordVisibility() =>
      emit(state.copyWith(showPassword: !state.showPassword));

  void hidePassword() {
    if (state.showPassword) emit(state.copyWith(showPassword: false));
  }

  /// Validates the form; on success the flow waits for the OTP.
  void submit() {
    if (state.isBusy) return;
    final nameError = Validators.validateName(state.name);
    final emailError = Validators.validateEmail(state.email);
    final phoneError = Validators.validatePhone(state.phone);
    final passwordError = Validators.validatePassword(_passphrase);
    final valid =
        nameError == null &&
        emailError == null &&
        phoneError == null &&
        passwordError == null;
    emit(
      state.copyWith(
        submitted: true,
        nameError: nameError,
        emailError: emailError,
        phoneError: phoneError,
        passwordError: passwordError,
        name: valid ? state.name.trim() : state.name,
        email: valid ? state.email.trim() : state.email,
        phone: valid ? Validators.normalizePhone(state.phone) : state.phone,
        status: valid
            ? CreateAccountStatus.pendingVerification
            : CreateAccountStatus.editing,
        errorMessage: null,
      ),
    );
  }

  /// Called by the verification step after the OTP matched: stores the
  /// salted hash, re-keys the single on-device account (D-031) and signs in.
  Future<void> completeSignUp() async {
    if (_completing) return;
    if (state.status != CreateAccountStatus.pendingVerification &&
        state.status != CreateAccountStatus.failed) {
      return;
    }
    _completing = true;
    emit(
      state.copyWith(
        status: CreateAccountStatus.completing,
        errorMessage: null,
      ),
    );
    try {
      final stored = await _auth.setCredentials(
        email: state.email,
        password: _passphrase,
      );
      if (stored case Failure(:final message)) {
        _fail(message);
        return;
      }
      final saved = await _writeAccount();
      if (saved case Failure(:final message)) {
        _fail(message);
        return;
      }
      await _session.signIn(state.email, _passphrase);
      if (isClosed) return;
      switch (_session.state) {
        case SessionAuthenticated():
          _passphrase = '';
          emit(state.copyWith(status: CreateAccountStatus.completed));
        case SessionUnauthenticated(:final failure):
          _fail(failure?.message ?? 'Could not sign you in. Please try again.');
        case SessionUnknown() || SessionAuthenticating():
          _fail('Could not sign you in. Please try again.');
      }
    } finally {
      _completing = false;
    }
  }

  Future<Result<void>> _writeAccount() async {
    final current = await _users.getCurrentUser();
    switch (current) {
      case Failure(:final message, :final error):
        return Failure(message, error);
      case Success(data: final existing) when existing != null:
        return await _users.updateUser(
          existing.copyWith(
            fullName: state.name,
            email: state.email,
            phone: state.phone,
          ),
        );
      case Success():
        final now = _clock.now();
        return await _users.saveUser(
          User(
            id: 'user_${now.microsecondsSinceEpoch}',
            fullName: state.name,
            email: state.email,
            phone: state.phone,
            balance: DemoCredentials.openingBalance,
            createdAt: now,
          ),
        );
    }
  }

  void _fail(String message) {
    if (isClosed) return;
    emit(
      state.copyWith(status: CreateAccountStatus.failed, errorMessage: message),
    );
  }

  @override
  Future<void> close() {
    _passphrase = '';
    return super.close();
  }
}
