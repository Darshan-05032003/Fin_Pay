import 'package:flutter/foundation.dart';
import '../models/card.dart' as card_models;
import '../services/database_service.dart';

class CardProvider with ChangeNotifier {
  List<card_models.Card> _cards = [];
  bool _isLoading = false;
  final DatabaseService _db = DatabaseService();

  List<card_models.Card> get cards => _cards;
  bool get isLoading => _isLoading;

  Future<void> loadCards() async {
    _isLoading = true;
    notifyListeners();

    try {
      _cards = await _db.getCards();
    } catch (e) {
      debugPrint('Error loading cards: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCard(card_models.Card card) async {
    try {
      await _db.insertCard(card);
      _cards.add(card);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding card: $e');
    }
  }

  Future<void> deleteCard(String cardId) async {
    try {
      await _db.deleteCard(cardId);
      _cards.removeWhere((c) => c.id == cardId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting card: $e');
    }
  }
}

