import 'package:equatable/equatable.dart';
import '../../models/user.dart';

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
  final User user;

  const UpdateUserEvent(this.user);

  @override
  List<Object?> get props => [user];
}

/// Event to update user balance
class UpdateBalanceEvent extends UserEvent {
  final double newBalance;

  const UpdateBalanceEvent(this.newBalance);

  @override
  List<Object?> get props => [newBalance];
}

/// Event to authenticate user (login)
class LoginEvent extends UserEvent {
  final String email;
  final String password;

  const LoginEvent({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Event to logout user
class LogoutEvent extends UserEvent {
  const LogoutEvent();
}
