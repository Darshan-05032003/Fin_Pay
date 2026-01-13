import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/logger.dart';
import '../../services/database_service.dart';
import 'notification_event.dart';
import 'notification_state.dart';

/// BLoC for managing notification state
/// 
/// This BLoC handles all notification-related operations including:
/// - Loading notifications
/// - Adding new notifications
/// - Deleting notifications
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final DatabaseService _db = DatabaseService();

  NotificationBloc() : super(const NotificationInitial()) {
    on<LoadNotificationsEvent>(_onLoadNotifications);
    on<AddNotificationEvent>(_onAddNotification);
    on<DeleteNotificationEvent>(_onDeleteNotification);
  }

  /// Handle loading notifications
  Future<void> _onLoadNotifications(
    LoadNotificationsEvent event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());

    try {
      final notifications = await _db.getNotifications();
      emit(NotificationLoaded(notifications));
      Logger.info('Loaded ${notifications.length} notifications');
    } catch (e) {
      emit(NotificationError('Failed to load notifications: ${e.toString()}'));
      Logger.error('Error loading notifications', e);
    }
  }

  /// Handle adding a new notification
  Future<void> _onAddNotification(
    AddNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _db.insertNotification(event.notification);
      final currentState = state;
      if (currentState is NotificationLoaded) {
        final updatedNotifications = [event.notification, ...currentState.notifications];
        emit(NotificationLoaded(updatedNotifications));
      } else {
        add(const LoadNotificationsEvent());
      }
      Logger.info('Notification added successfully');
    } catch (e) {
      emit(NotificationError('Failed to add notification: ${e.toString()}'));
      Logger.error('Error adding notification', e);
    }
  }

  /// Handle deleting a notification
  Future<void> _onDeleteNotification(
    DeleteNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _db.deleteNotification(event.notificationId);
      final currentState = state;
      if (currentState is NotificationLoaded) {
        final updatedNotifications = currentState.notifications
            .where((n) => n.id != event.notificationId)
            .toList();
        emit(NotificationLoaded(updatedNotifications));
      }
      Logger.info('Notification deleted successfully');
    } catch (e) {
      emit(NotificationError('Failed to delete notification: ${e.toString()}'));
      Logger.error('Error deleting notification', e);
    }
  }
}
