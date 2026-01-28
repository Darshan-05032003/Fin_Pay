class NotificationItem {

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
  });
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final NotificationType type;
}

enum NotificationType {
  cashback,
  paymentReminder,
  profileUpdate,
  paymentRequest,
  cardLinked,
  billDue,
}

