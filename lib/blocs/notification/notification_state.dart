import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/notification_item.dart';

/// Base class for all notification-related states
abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

/// Initial state when notification bloc is created
class NotificationInitial extends NotificationState {
  const NotificationInitial();
}

/// State when notifications are being loaded
class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

/// State when notifications are successfully loaded
class NotificationLoaded extends NotificationState {

  const NotificationLoaded(this.notifications);
  final List<NotificationItem> notifications;

  @override
  List<Object?> get props => [notifications];

  int get unreadCount => notifications.length;
}

/// State when an error occurs
class NotificationError extends NotificationState {

  const NotificationError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
