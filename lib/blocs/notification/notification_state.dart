import 'package:equatable/equatable.dart';
import '../../models/notification_item.dart';

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
  final List<NotificationItem> notifications;

  const NotificationLoaded(this.notifications);

  @override
  List<Object?> get props => [notifications];

  int get unreadCount => notifications.length;
}

/// State when an error occurs
class NotificationError extends NotificationState {
  final String message;

  const NotificationError(this.message);

  @override
  List<Object?> get props => [message];
}
