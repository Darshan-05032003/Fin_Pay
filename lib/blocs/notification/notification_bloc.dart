import 'dart:async';

import 'package:fin_pay/blocs/notification/notification_event.dart';
import 'package:fin_pay/blocs/notification/notification_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/notification_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lists, adds and deletes in-app notifications.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc({required INotificationRepository repository})
    : _repository = repository,
      super(const NotificationInitial()) {
    on<LoadNotificationsEvent>(_onLoad);
    on<AddNotificationEvent>(_onAdd);
    on<DeleteNotificationEvent>(_onDelete);
  }

  final INotificationRepository _repository;
  final StreamController<NotificationEffect> _effects =
      StreamController.broadcast();

  /// One-off effects for the UI.
  Stream<NotificationEffect> get effects => _effects.stream;

  Future<void> _onLoad(
    LoadNotificationsEvent event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationLoading());
    final result = await _repository.getNotifications();
    switch (result) {
      case Success(data: final items) when items.isEmpty:
        emit(const NotificationEmpty());
      case Success(data: final items):
        emit(NotificationContent(items));
      case Failure(:final message):
        emit(NotificationError(message));
        Logger.error('Failed to load notifications: $message');
    }
  }

  Future<void> _onAdd(
    AddNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final result = await _repository.addNotification(event.notification);
    switch (result) {
      case Success():
        _effects.add(NotificationAdded(event.notification));
        final current = state;
        if (current is NotificationContent) {
          emit(
            NotificationContent([event.notification, ...current.notifications]),
          );
        } else {
          emit(NotificationContent([event.notification]));
        }
      case Failure(:final message):
        _effects.add(NotificationFailed(message));
        Logger.error('Failed to add notification: $message');
    }
  }

  Future<void> _onDelete(
    DeleteNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    final removed = current is NotificationContent
        ? current.notifications
              .where((n) => n.id == event.notificationId)
              .firstOrNull
        : null;
    final result = await _repository.deleteNotification(event.notificationId);
    switch (result) {
      case Success():
        if (removed != null) _effects.add(NotificationDeleted(removed));
        if (current is NotificationContent) {
          final remaining = current.notifications
              .where((n) => n.id != event.notificationId)
              .toList();
          emit(
            remaining.isEmpty
                ? const NotificationEmpty()
                : NotificationContent(remaining),
          );
        }
      case Failure(:final message):
        _effects.add(NotificationFailed(message));
        Logger.error('Failed to delete notification: $message');
    }
  }

  @override
  Future<void> close() async {
    await _effects.close();
    await super.close();
  }
}
