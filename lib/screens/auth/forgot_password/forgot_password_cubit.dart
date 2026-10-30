import 'package:equatable/equatable.dart';
import 'package:fin_pay/utils/validators.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ForgotPasswordStatus { idle, submitting, sent }

class ForgotPasswordState extends Equatable {
  const ForgotPasswordState({
    this.email = '',
    this.emailError,
    this.status = ForgotPasswordStatus.idle,
    this.submitted = false,
  });

  final String email;
  final String? emailError;
  final ForgotPasswordStatus status;
  final bool submitted;

  ForgotPasswordState copyWith({
    String? email,
    Object? emailError = _keep,
    ForgotPasswordStatus? status,
    bool? submitted,
  }) => ForgotPasswordState(
    email: email ?? this.email,
    emailError: emailError == _keep ? this.emailError : emailError as String?,
    status: status ?? this.status,
    submitted: submitted ?? this.submitted,
  );

  static const Object _keep = Object();

  @override
  List<Object?> get props => [email, emailError, status, submitted];
}

/// The "forgot password" email step. Sending is simulated locally: every
/// well-formed address gets the same "sent" outcome after [delay], so the
/// screen cannot be used to find out which addresses have an account.
class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit({this.delay = const Duration(milliseconds: 900)})
    : super(const ForgotPasswordState());

  /// Simulated network time.
  final Duration delay;

  /// How many reset links were "sent" (tests).
  int sends = 0;

  void emailChanged(String value) {
    emit(
      state.copyWith(
        email: value,
        emailError: state.submitted ? Validators.validateEmail(value) : null,
      ),
    );
  }

  Future<void> submit() async {
    if (state.status != ForgotPasswordStatus.idle) return;
    final error = Validators.validateEmail(state.email);
    if (error != null) {
      emit(state.copyWith(submitted: true, emailError: error));
      return;
    }
    emit(
      state.copyWith(
        submitted: true,
        emailError: null,
        status: ForgotPasswordStatus.submitting,
      ),
    );
    await Future<void>.delayed(delay);
    if (isClosed) return;
    sends++;
    emit(state.copyWith(status: ForgotPasswordStatus.sent));
  }

  /// Back to the form (same address prefilled).
  void reset() => emit(state.copyWith(status: ForgotPasswordStatus.idle));
}
