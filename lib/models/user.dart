class User {
  User({
    required this.id,
    required this.fullName,
    required this.email,
    required this.password,
    required this.createdAt,
    this.phone,
    this.balance = 0.0,
    this.profileImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      password: json['password'] as String,
      balance: (json['balance'] as num? ?? 0.0).toDouble(),
      profileImageUrl: json['profileImageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String password;
  final double balance;
  final String? profileImageUrl;
  final DateTime createdAt;

  User copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? password,
    double? balance,
    String? profileImageUrl,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      balance: balance ?? this.balance,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'balance': balance,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
