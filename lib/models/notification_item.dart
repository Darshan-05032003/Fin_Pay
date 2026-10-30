import 'package:equatable/equatable.dart';

/// What a notification is about.
enum NotificationType {
  cashback,
  paymentReminder,
  profileUpdate,
  paymentRequest,
  cardLinked,
  billDue;

  /// Parses both `cashback` and the legacy `NotificationType.cashback`;
  /// unknown → [cashback].
  static NotificationType parse(String? value) {
    final name = value?.split('.').last;
    return NotificationType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => NotificationType.cashback,
    );
  }
}

/// An in-app notification. Immutable value type; [time] is stored in UTC.
class NotificationItem extends Equatable {
  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required DateTime time,
    required this.type,
    this.isRead = false,
  }) : time = time.toUtc();

  /// Reads a notification from JSON written by [toJson] (or a sqflite row).
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      time: DateTime.parse(json['time'] as String),
      type: NotificationType.parse(json['type'] as String?),
      isRead: (json['isRead'] as int? ?? 0) == 1,
    );
  }

  final String id;
  final String title;
  final String message;
  final DateTime time;
  final NotificationType type;
  final bool isRead;

  /// The notification instant in the device's local time zone.
  DateTime get localTime => time.toLocal();

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? time,
    NotificationType? type,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      time: time ?? this.time,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'time': time.toIso8601String(),
    'type': type.name,
    'isRead': isRead ? 1 : 0,
  };

  @override
  List<Object?> get props => [id, title, message, time, type, isRead];
}
