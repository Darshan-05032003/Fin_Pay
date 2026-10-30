import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/models/user.dart';

/// State of the account holder record.
sealed class UserState extends Equatable {
  const UserState();

  /// The user when loaded, otherwise null.
  User? get user => null;

  @override
  List<Object?> get props => [];
}

final class UserInitial extends UserState {
  const UserInitial();
}

final class UserLoading extends UserState {
  const UserLoading();
}

/// No user row exists (before the demo account is seeded, or after reset).
final class UserEmpty extends UserState {
  const UserEmpty();
}

final class UserError extends UserState {
  const UserError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class UserContent extends UserState {
  const UserContent(this._user);

  final User _user;

  @override
  User get user => _user;

  Money get balance => _user.balance;
  String get userName => _user.fullName;

  @override
  List<Object?> get props => [_user];
}

/// One-off effects for the UI.
sealed class UserEffect extends Equatable {
  const UserEffect();

  @override
  List<Object?> get props => [];
}

final class UserUpdated extends UserEffect {
  const UserUpdated();
}

final class UserUpdateFailed extends UserEffect {
  const UserUpdateFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
