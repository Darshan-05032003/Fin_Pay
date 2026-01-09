import 'package:flutter/foundation.dart';
import '../models/transaction.dart' as models;
import '../services/database_service.dart';

class TransactionProvider with ChangeNotifier {
  List<models.Transaction> _transactions = [];
  bool _isLoading = false;
  final DatabaseService _db = DatabaseService();

  List<models.Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  
  List<models.Transaction> get recentTransactions {
    return List<models.Transaction>.from(_transactions.take(5));
  }
  
  double get totalIncome {
    return _transactions
        .where((t) => t.amount > 0)
        .fold(0.0, (sum, t) => sum + t.amount);
  }
  
  double get totalExpenses {
    return _transactions
        .where((t) => t.amount < 0)
        .fold(0.0, (sum, t) => sum + t.amount.abs());
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = List<models.Transaction>.from(await _db.getTransactions());
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(models.Transaction transaction) async {
    try {
      await _db.insertTransaction(transaction);
      _transactions.insert(0, transaction);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding transaction: $e');
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _db.deleteTransaction(transactionId);
      _transactions.removeWhere((t) => t.id == transactionId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
    }
  }
}

