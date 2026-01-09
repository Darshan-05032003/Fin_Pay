import 'package:flutter/foundation.dart';
import '../models/notification_item.dart';
import '../services/database_service.dart';

class NotificationProvider with ChangeNotifier {
  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  final DatabaseService _db = DatabaseService();

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  
  int get unreadCount => _notifications.length;

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _db.getNotifications();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNotification(NotificationItem notification) async {
    try {
      await _db.insertNotification(notification);
      _notifications.insert(0, notification);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding notification: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.deleteNotification(notificationId);
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
}

