import 'dart:async';

import 'package:fin_pay/blocs/notification/notification_event.dart';
import 'package:fin_pay/blocs/notification/notification_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/notification_repository.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lists, adds and deletes in-app notifications.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc({required INotificationRepository repository})
    : _repository = repository,
      super(const NotificationInitial()) {
    on<LoadNotificationsEvent>(_onLoad);
    on<AddNotificationEvent>(_onAdd);
    on<DeleteNotificationEvent>(_onDelete);
    on<MarkNotificationReadEvent>(_onMarkRead);
    on<MarkAllNotificationsReadEvent>(_onMarkAllRead);
  }

  /// Inserts [item] where storage order (newest first) puts it; on a tie
  /// the new item goes first.
  static List<NotificationItem> _insertNewestFirst(
    List<NotificationItem> items,
    NotificationItem item,
  ) {
    final rest = items.where((n) => n.id != item.id).toList();
    final at = rest.indexWhere((n) => !n.time.isAfter(item.time));
    return at < 0 ? [...rest, item] : [...rest]
      ..insert(at, item);
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
        _emitEffect(NotificationAdded(event.notification));
        final current = state;
        if (current is NotificationContent) {
          // Storage replaces by id, so an undo replayed twice (or a
          // duplicate add) keeps one row; the list keeps storage order.
          emit(
            NotificationContent(
              _insertNewestFirst(current.notifications, event.notification),
            ),
          );
        } else {
          emit(NotificationContent([event.notification]));
        }
      case Failure(:final message):
        _emitEffect(NotificationFailed(message));
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
        if (removed != null) _emitEffect(NotificationDeleted(removed));
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
        _emitEffect(NotificationFailed(message));
        Logger.error('Failed to delete notification: $message');
    }
  }

  Future<void> _onMarkRead(
    MarkNotificationReadEvent event,
    Emitter<NotificationState> emit,
  ) => _markRead([event.notificationId], emit);

  Future<void> _onMarkAllRead(
    MarkAllNotificationsReadEvent event,
    Emitter<NotificationState> emit,
  ) {
    final current = state;
    if (current is! NotificationContent) return Future.value();
    return _markRead([
      for (final n in current.notifications)
        if (!n.isRead) n.id,
    ], emit);
  }

  Future<void> _markRead(
    List<String> ids,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationContent) return;
    final unread = ids
        .where(
          (id) => current.notifications.any((n) => n.id == id && !n.isRead),
        )
        .toSet();
    if (unread.isEmpty) return;
    final result = await _repository.markRead(unread.toList());
    switch (result) {
      case Success():
        final latest = state;
        if (latest is! NotificationContent) return;
        emit(
          NotificationContent([
            for (final n in latest.notifications)
              if (unread.contains(n.id)) n.copyWith(isRead: true) else n,
          ]),
        );
      case Failure(:final message):
        _emitEffect(NotificationFailed(message));
        Logger.error('Failed to mark notifications read: $message');
    }
  }

  /// A handler that was awaiting storage when the bloc closed must not
  /// throw into a closed controller.
  void _emitEffect(NotificationEffect effect) {
    if (!_effects.isClosed) _effects.add(effect);
  }

  @override
  Future<void> close() async {
    await _effects.close();
    await super.close();
  }
}
