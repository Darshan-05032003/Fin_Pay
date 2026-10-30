import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';

/// The account holder. Immutable value type.
///
/// Credentials are never part of the user record: they live as a salted hash
/// in secure storage (see `AuthRepository`).
class User extends Equatable {
  User({
    required this.id,
    required this.fullName,
    required this.email,
    required DateTime createdAt,
    this.phone,
    this.balance = Money.zero,
    this.profileImageUrl,
  }) : createdAt = createdAt.toUtc();

  /// Reads a user from JSON written by [toJson] (or a sqflite row). A legacy
  /// `password` key is ignored.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      balance: Money.fromJson(json['balance'] ?? 0),
      profileImageUrl: json['profileImageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final Money balance;
  final String? profileImageUrl;
  final DateTime createdAt;

  User copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    Money? balance,
    String? profileImageUrl,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      balance: balance ?? this.balance,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'balance': balance.toJson(),
    'profileImageUrl': profileImageUrl,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [
    id,
    fullName,
    email,
    phone,
    balance,
    profileImageUrl,
    createdAt,
  ];
}
