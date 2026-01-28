import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/notification_item.dart';

/// Base class for all notification-related events
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load notifications
class LoadNotificationsEvent extends NotificationEvent {
  const LoadNotificationsEvent();
}

/// Event to add a new notification
class AddNotificationEvent extends NotificationEvent {

  const AddNotificationEvent(this.notification);
  final NotificationItem notification;

  @override
  List<Object?> get props => [notification];
}

/// Event to delete a notification
class DeleteNotificationEvent extends NotificationEvent {

  const DeleteNotificationEvent(this.notificationId);
  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}
