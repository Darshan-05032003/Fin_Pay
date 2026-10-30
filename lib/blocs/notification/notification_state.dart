import 'package:equatable/equatable.dart';
import 'package:fin_pay/models/notification_item.dart';

/// State of the notification list.
sealed class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

final class NotificationInitial extends NotificationState {
  const NotificationInitial();
}

final class NotificationLoading extends NotificationState {
  const NotificationLoading();
}

final class NotificationEmpty extends NotificationState {
  const NotificationEmpty();
}

final class NotificationError extends NotificationState {
  const NotificationError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class NotificationContent extends NotificationState {
  const NotificationContent(this.notifications);

  final List<NotificationItem> notifications;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  @override
  List<Object?> get props => [notifications];
}

/// One-off effects for the UI.
sealed class NotificationEffect extends Equatable {
  const NotificationEffect();

  @override
  List<Object?> get props => [];
}

final class NotificationAdded extends NotificationEffect {
  const NotificationAdded(this.notification);

  final NotificationItem notification;

  @override
  List<Object?> get props => [notification];
}

final class NotificationDeleted extends NotificationEffect {
  const NotificationDeleted(this.notification);

  /// The removed item, so the UI can offer undo.
  final NotificationItem notification;

  @override
  List<Object?> get props => [notification];
}

final class NotificationFailed extends NotificationEffect {
  const NotificationFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
