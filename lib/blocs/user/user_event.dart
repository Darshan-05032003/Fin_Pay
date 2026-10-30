import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/models/user.dart';

sealed class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

/// Reads the user from storage.
final class LoadUserEvent extends UserEvent {
  const LoadUserEvent();
}

/// Persists an edited user.
final class UpdateUserEvent extends UserEvent {
  const UpdateUserEvent(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

/// Sets the balance to an absolute value.
final class UpdateBalanceEvent extends UserEvent {
  const UpdateBalanceEvent(this.newBalance);

  final Money newBalance;

  @override
  List<Object?> get props => [newBalance];
}

/// Clears the in-memory user (the row stays; the session is cleared by
/// `SessionCubit`).
final class ClearUserEvent extends UserEvent {
  const ClearUserEvent();
}
