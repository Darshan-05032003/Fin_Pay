import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/user.dart';

/// Why a sign-in attempt did not produce a session.
sealed class AuthFailure extends Equatable {
  const AuthFailure();

  /// Short, user-facing explanation.
  String get message;

  @override
  List<Object?> get props => [];
}

/// Wrong email or password. Deliberately does not say which.
final class InvalidCredentials extends AuthFailure {
  const InvalidCredentials({required this.remainingAttempts});

  /// Attempts left before [AccountLocked].
  final int remainingAttempts;

  @override
  String get message => remainingAttempts > 0
      ? 'Incorrect email or password. $remainingAttempts '
            '${remainingAttempts == 1 ? 'attempt' : 'attempts'} left.'
      : 'Incorrect email or password.';

  @override
  List<Object?> get props => [remainingAttempts];
}

/// Too many failures; try again after [until].
final class AccountLocked extends AuthFailure {
  const AccountLocked({required this.until, required this.remaining});

  final DateTime until;
  final Duration remaining;

  @override
  String get message {
    final seconds = remaining.inSeconds.clamp(1, 1 << 31);
    return 'Too many attempts. Try again in $seconds s.';
  }

  @override
  List<Object?> get props => [until, remaining];
}

/// The credential store (secure storage or the database) failed.
final class CredentialStoreUnavailable extends AuthFailure {
  const CredentialStoreUnavailable(this.detail);

  final String detail;

  @override
  String get message => 'Could not check your credentials. Please try again.';

  @override
  List<Object?> get props => [detail];
}

/// The outcome of a sign-in attempt.
sealed class AuthResult extends Equatable {
  const AuthResult();

  @override
  List<Object?> get props => [];
}

/// Credentials verified; [user] is the signed-in account.
final class AuthSuccess extends AuthResult {
  const AuthSuccess(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

/// Credentials rejected or could not be checked.
final class AuthFailed extends AuthResult {
  const AuthFailed(this.failure);

  final AuthFailure failure;

  @override
  List<Object?> get props => [failure];
}
