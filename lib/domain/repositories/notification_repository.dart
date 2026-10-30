import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/models/notification_item.dart';

/// Repository interface for in-app notifications.
abstract interface class INotificationRepository {
  Future<Result<List<NotificationItem>>> getNotifications({int? limit});
  Future<Result<void>> addNotification(NotificationItem notification);
  Future<Result<void>> deleteNotification(String notificationId);
}
