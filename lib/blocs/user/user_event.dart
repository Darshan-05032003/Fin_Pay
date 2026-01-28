import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/user.dart';

/// Base class for all user-related events
abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load user data
class LoadUserEvent extends UserEvent {
  const LoadUserEvent();
}

/// Event to update user information
class UpdateUserEvent extends UserEvent {

  const UpdateUserEvent(this.user);
  final User user;

  @override
  List<Object?> get props => [user];
}

/// Event to update user balance
class UpdateBalanceEvent extends UserEvent {

  const UpdateBalanceEvent(this.newBalance);
  final double newBalance;

  @override
  List<Object?> get props => [newBalance];
}

/// Event to authenticate user (login)
class LoginEvent extends UserEvent {

  const LoginEvent({
    required this.email,
    required this.password,
  });
  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Event to logout user
class LogoutEvent extends UserEvent {
  const LogoutEvent();
}
