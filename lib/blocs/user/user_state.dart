import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/user.dart';

/// Base class for all user-related states
abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

/// Initial state when user bloc is created
class UserInitial extends UserState {
  const UserInitial();
}

/// State when user data is being loaded
class UserLoading extends UserState {
  const UserLoading();
}

/// State when user data is successfully loaded
class UserLoaded extends UserState {

  const UserLoaded(this.user);
  final User? user;

  @override
  List<Object?> get props => [user];

  double get balance => user?.balance ?? 0.0;
  String get userName => user?.fullName ?? 'User';
  bool get isAuthenticated => user != null;
}

/// State when an error occurs
class UserError extends UserState {

  const UserError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
