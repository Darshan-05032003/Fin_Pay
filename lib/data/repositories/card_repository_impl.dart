import 'dart:convert';

import 'package:fin_pay/core/errors/app_exception.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/storage/secure_storage.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/models/payment_card.dart';

/// [ICardRepository]: masked rows in sqflite, PAN/CVV in secure storage.
class CardRepositoryImpl implements ICardRepository {
  CardRepositoryImpl(this._localDataSource, this._secureStorage);

  final LocalDataSource _localDataSource;
  final SecureStorage _secureStorage;

  /// Secure-storage key for a card's PAN and CVV.
  static String vaultKey(String cardId) => 'card:$cardId';

  @override
  Future<Result<List<PaymentCard>>> getCards() async {
    final rows = await _localDataSource.getCards();
    return await rows.flatMapAsync((cards) async {
      final enriched = <PaymentCard>[];
      for (final card in cards) {
        try {
          enriched.add(await _attachVaulted(card));
        } on SecureStorageException {
          // Vault unavailable: still show the masked card.
          enriched.add(card);
        } on FormatException {
          enriched.add(card);
        }
      }
      return Success(enriched);
    });
  }

  Future<PaymentCard> _attachVaulted(PaymentCard card) async {
    final raw = await _secureStorage.read(vaultKey(card.id));
    if (raw == null) return card;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return card.copyWith(
      cardNumber: json['cardNumber'] as String? ?? card.cardNumber,
      cvv: json['cvv'] as String? ?? '',
    );
  }

  @override
  Future<Result<void>> addCard(PaymentCard card) async {
    try {
      await _secureStorage.write(
        vaultKey(card.id),
        jsonEncode({'cardNumber': card.cardNumber, 'cvv': card.cvv}),
      );
    } on SecureStorageException catch (e) {
      return Failure('Could not store card securely', e);
    }
    final saved = await _localDataSource.saveCard(card);
    if (saved.isFailure) {
      // Do not leave orphaned vault entries behind.
      try {
        await _secureStorage.delete(vaultKey(card.id));
      } on SecureStorageException {
        // Best effort.
      }
    }
    return saved;
  }

  @override
  Future<Result<String?>> readCvv(String cardId) async {
    try {
      final raw = await _secureStorage.read(vaultKey(cardId));
      if (raw == null) return const Success(null);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return Success(json['cvv'] as String?);
    } on SecureStorageException catch (e) {
      return Failure('Could not read the card securely', e);
    } on FormatException catch (e) {
      return Failure('Stored card details are unreadable', e);
    }
  }

  @override
  Future<Result<void>> deleteCard(String cardId) async {
    final deleted = await _localDataSource.deleteCard(cardId);
    return await deleted.flatMapAsync((_) async {
      try {
        await _secureStorage.delete(vaultKey(cardId));
        return const Success(null);
      } on SecureStorageException catch (e) {
        return Failure(
          'Card removed but its PAN and CVV could not be deleted',
          DatabaseException('secure storage', e),
        );
      }
    });
  }
}
