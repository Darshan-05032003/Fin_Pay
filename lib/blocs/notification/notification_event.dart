import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/notification_item.dart';

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

final class LoadNotificationsEvent extends NotificationEvent {
  const LoadNotificationsEvent();
}

final class AddNotificationEvent extends NotificationEvent {
  const AddNotificationEvent(this.notification);

  final NotificationItem notification;

  @override
  List<Object?> get props => [notification];
}

final class DeleteNotificationEvent extends NotificationEvent {
  const DeleteNotificationEvent(this.notificationId);

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}

/// Flags one notification as read (F6; a no-op when it already is).
final class MarkNotificationReadEvent extends NotificationEvent {
  const MarkNotificationReadEvent(this.notificationId);

  final String notificationId;

  @override
  List<Object?> get props => [notificationId];
}

/// Flags every loaded notification as read (F6).
final class MarkAllNotificationsReadEvent extends NotificationEvent {
  const MarkAllNotificationsReadEvent();
}
