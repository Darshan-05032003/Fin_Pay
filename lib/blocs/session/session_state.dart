import 'package:equatable/equatable.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/models/user.dart';

/// Whether somebody is signed in. Drives the router's redirect.
sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

/// Not yet restored from storage (app start).
final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

/// A sign-in attempt is in flight.
final class SessionAuthenticating extends SessionState {
  const SessionAuthenticating();
}

/// Signed in as [userId].
final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}

/// Signed out; [failure] holds the reason the last attempt did not succeed.
final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated({this.failure});

  final AuthFailure? failure;

  @override
  List<Object?> get props => [failure];
}

/// One-off side effects of the session, delivered on a separate stream so
/// the UI (snackbars, haptics, navigation) reacts exactly once.
sealed class SessionEffect extends Equatable {
  const SessionEffect();

  @override
  List<Object?> get props => [];
}

final class SignedIn extends SessionEffect {
  const SignedIn(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

final class SignInFailed extends SessionEffect {
  const SignInFailed(this.failure);

  final AuthFailure failure;

  @override
  List<Object?> get props => [failure];
}

final class SignedOut extends SessionEffect {
  const SignedOut();
}
