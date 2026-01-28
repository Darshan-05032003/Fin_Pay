import 'package:fin_pay/blocs/notification/notification_event.dart';
import 'package:fin_pay/blocs/notification/notification_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/services/database_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// BLoC for managing notification state
/// 
/// This BLoC handles all notification-related operations including:
/// - Loading notifications
/// - Adding new notifications
/// - Deleting notifications
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {

  NotificationBloc({required DatabaseService db}) : _db = db, super(const NotificationInitial()) {
    on<LoadNotificationsEvent>(_onLoadNotifications);
    on<AddNotificationEvent>(_onAddNotification);
    on<DeleteNotificationEvent>(_onDeleteNotification);
  }
  final DatabaseService _db;

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
      emit(NotificationError('Failed to load notifications: $e'));
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
      emit(NotificationError('Failed to add notification: $e'));
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
      emit(NotificationError('Failed to delete notification: $e'));
      Logger.error('Error deleting notification', e);
    }
  }
}
