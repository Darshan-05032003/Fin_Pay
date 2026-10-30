import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/domain/repositories/notification_repository.dart';
import 'package:fin_pay/models/notification_item.dart';

/// [INotificationRepository] over the local data source.
class NotificationRepositoryImpl implements INotificationRepository {
  NotificationRepositoryImpl(this._localDataSource);

  final LocalDataSource _localDataSource;

  @override
  Future<Result<List<NotificationItem>>> getNotifications({int? limit}) =>
      _localDataSource.getNotifications(limit: limit);

  @override
  Future<Result<void>> addNotification(NotificationItem notification) =>
      _localDataSource.saveNotification(notification);

  @override
  Future<Result<void>> deleteNotification(String notificationId) =>
      _localDataSource.deleteNotification(notificationId);
}
