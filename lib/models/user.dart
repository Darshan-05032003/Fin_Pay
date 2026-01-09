class User {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String password;
  final double balance;
  final String? profileImageUrl;
  final DateTime createdAt;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.password,
    this.balance = 0.0,
    this.profileImageUrl,
    required this.createdAt,
  });

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

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
      phone: json['phone'],
      password: json['password'],
      balance: (json['balance'] ?? 0.0).toDouble(),
      profileImageUrl: json['profileImageUrl'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

