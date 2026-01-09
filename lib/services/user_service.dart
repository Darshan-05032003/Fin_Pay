import '../models/user.dart';
import '../models/card.dart' as card_models;
import '../models/transaction.dart';
import '../models/notification_item.dart';
import 'database_service.dart';

class UserService {
  // Default credentials - ONLY these will work
  static const String defaultEmail = 'user@finpay.com';
  static const String defaultPassword = 'FinPay123';
  static const String defaultName = 'John Doe';

  static final DatabaseService _db = DatabaseService();

  // Initialize default user if no user exists
  static Future<void> init() async {
    final user = await _db.getUser();
    if (user == null) {
      // Create default user
      final defaultUser = User(
        id: 'default_user_001',
        fullName: defaultName,
        email: defaultEmail,
        password: defaultPassword,
        balance: 56246.90,
        createdAt: DateTime.now(),
      );
      await _db.insertUser(defaultUser);
    }
  }

  static Future<void> saveUser(User user) async {
    await _db.insertUser(user);
  }

  static Future<User?> getCurrentUser() async {
    return await _db.getUser();
  }
  
  // Login method that only accepts default credentials
  static Future<bool> loginUser(String email, String password) async {
    // Only allow default credentials
    if (email.trim().toLowerCase() == defaultEmail.toLowerCase() && 
        password == defaultPassword) {
      // Ensure default user exists
      await init();
      return true;
    }
    return false;
  }

  static Future<void> updateUser(User user) async {
    await _db.updateUser(user);
  }

  static Future<void> updateBalance(double balance) async {
    final user = await getCurrentUser();
    if (user != null) {
      await _db.updateUser(user.copyWith(balance: balance));
    }
  }

  static Future<double> getBalance() async {
    final user = await getCurrentUser();
    return user?.balance ?? 0.0;
  }

  // Cards Management - Now using database
  static Future<List<card_models.Card>> getCards() async {
    return await _db.getCards();
  }

  static Future<void> addCard(card_models.Card card) async {
    await _db.insertCard(card);
  }

  // Transactions Management - Now using database
  static Future<List<Transaction>> getTransactions() async {
    return await _db.getTransactions();
  }

  static Future<void> addTransaction(Transaction transaction) async {
    await _db.insertTransaction(transaction);
    
    // Update balance
    final user = await getCurrentUser();
    if (user != null) {
      final newBalance = user.balance + transaction.amount;
      await updateBalance(newBalance);
    }
  }

  static Future<void> saveTransactions(List<Transaction> transactions) async {
    // Clear and re-insert all transactions
    final existing = await getTransactions();
    for (var t in existing) {
      await _db.deleteTransaction(t.id);
    }
    for (var t in transactions) {
      await _db.insertTransaction(t);
    }
  }

  // Notifications Management - Now using database
  static Future<List<NotificationItem>> getNotifications() async {
    return await _db.getNotifications();
  }

  static Future<void> addNotification(NotificationItem notification) async {
    await _db.insertNotification(notification);
  }

  static Future<void> saveNotifications(List<NotificationItem> notifications) async {
    // Clear and re-insert all notifications
    final existing = await getNotifications();
    for (var n in existing) {
      await _db.deleteNotification(n.id);
    }
    for (var n in notifications) {
      await _db.insertNotification(n);
    }
  }

  static Future<void> logout() async {
    await _db.deleteUser();
  }
}

