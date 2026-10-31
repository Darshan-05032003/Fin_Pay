import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:fin_pay/domain/repositories/contact_repository.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/transfer/transfer/amount_input.dart';
import 'package:fin_pay/screens/transfer/transfer/contact_search.dart';
import 'package:fin_pay/screens/transfer/transfer/transfer_rules.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where the transfer form is.
enum TransferStatus { loading, content, error }

/// Immutable state of the transfer (amount) screen.
///
/// `toString` prints only the status: the state carries the balance and
/// the typed amount, which must not land in bloc-observer logs.
class TransferState extends Equatable {
  const TransferState({
    this.status = TransferStatus.loading,
    this.contacts = const [],
    this.recentRecipients = const [],
    this.query = '',
    this.selectedId,
    this.amount = AmountInput.empty,
    this.note = '',
    this.balance = Money.zero,
    this.shakes = 0,
    this.message,
  });

  final TransferStatus status;

  /// Every contact, unfiltered.
  final List<Contact> contacts;

  /// Names recently paid, newest first.
  final List<String> recentRecipients;
  final String query;
  final String? selectedId;
  final AmountInput amount;
  final String note;
  final Money balance;

  /// Incremented every time the amount should shake (invalid paste, or a
  /// key that pushed the amount into an error).
  final int shakes;

  /// Load error message.
  final String? message;

  /// Contacts matching [query], recently paid first.
  List<Contact> get visibleContacts => ContactSearch.rank(
    contacts,
    query: query,
    recentRecipients: recentRecipients,
  );

  Contact? get selected =>
      contacts.where((c) => c.id == selectedId).firstOrNull;

  AmountError? get amountError => amount.isEmpty
      ? null
      : AmountRules.validate(amount.money, balance: balance);

  /// Inline message under the amount, if any.
  String? get amountMessage {
    final error = amountError;
    return error == null ? null : AmountRules.message(error, balance: balance);
  }

  bool get canContinue =>
      status == TransferStatus.content &&
      selected != null &&
      AmountRules.canContinue(amount, balance: balance);

  TransferState copyWith({
    TransferStatus? status,
    List<Contact>? contacts,
    List<String>? recentRecipients,
    String? query,
    String? selectedId,
    AmountInput? amount,
    String? note,
    Money? balance,
    int? shakes,
    String? message,
  }) => TransferState(
    status: status ?? this.status,
    contacts: contacts ?? this.contacts,
    recentRecipients: recentRecipients ?? this.recentRecipients,
    query: query ?? this.query,
    selectedId: selectedId ?? this.selectedId,
    amount: amount ?? this.amount,
    note: note ?? this.note,
    balance: balance ?? this.balance,
    shakes: shakes ?? this.shakes,
    message: message ?? this.message,
  );

  @override
  List<Object?> get props => [
    status,
    contacts,
    recentRecipients,
    query,
    selectedId,
    amount,
    note,
    balance,
    shakes,
    message,
  ];

  @override
  String toString() => 'TransferState(${status.name})';
}

/// Drives the transfer form: loads contacts, the live balance and the
/// recently paid names; edits the amount through the keypad, chips or a
/// paste; and mints a [TransferDraft] with a fresh idempotency key when the
/// user continues.
class TransferCubit extends Cubit<TransferState> {
  TransferCubit({
    required IContactRepository contacts,
    required IUserRepository users,
    required ITransactionRepository transactions,
    Clock? clock,
    Random? random,
  }) : _contacts = contacts,
       _users = users,
       _transactions = transactions,
       _clock = clock ?? const Clock(),
       _random = random ?? Random.secure(),
       super(const TransferState());

  final IContactRepository _contacts;
  final IUserRepository _users;
  final ITransactionRepository _transactions;
  final Clock _clock;
  final Random _random;
  int _generation = 0;

  /// Loads everything. Safe to call again (retry).
  Future<void> load() async {
    final generation = ++_generation;
    emit(state.copyWith(status: TransferStatus.loading));
    final (contacts, user, recent) = await (
      _contacts.getContacts(),
      _users.getCurrentUser(),
      _transactions.getRecentTransactions(limit: 20),
    ).wait;
    if (isClosed || generation != _generation) return;
    if (contacts case Failure(:final message)) {
      emit(state.copyWith(status: TransferStatus.error, message: message));
      return;
    }
    if (user is Failure) {
      emit(
        state.copyWith(
          status: TransferStatus.error,
          message: 'Could not read your balance',
        ),
      );
      return;
    }
    final list = (contacts as Success<List<Contact>>).data;
    final balance = switch (user) {
      Success(data: final u) => u?.balance ?? Money.zero,
      _ => Money.zero,
    };
    final recentNames = switch (recent) {
      Success(data: final txns) => ContactSearch.recentRecipients(txns),
      _ => const <String>[],
    };
    emit(
      TransferState(
        status: TransferStatus.content,
        contacts: list,
        recentRecipients: recentNames,
        balance: balance,
        query: state.query,
        selectedId: list.any((c) => c.id == state.selectedId)
            ? state.selectedId
            : null,
        amount: state.amount,
        note: state.note,
        shakes: state.shakes,
      ),
    );
  }

  void queryChanged(String query) => emit(state.copyWith(query: query));

  void selectContact(String id) {
    if (!state.contacts.any((c) => c.id == id)) return;
    emit(state.copyWith(selectedId: id));
  }

  void digit(int digit) => _setAmount(state.amount.digit(digit));

  void decimal() => _setAmount(state.amount.decimal());

  void backspace() => _setAmount(state.amount.backspace());

  /// Long-press on backspace.
  void clearAmount() => _setAmount(AmountInput.empty);

  /// Replaces the amount with a quick chip.
  void quickAmount(Money money) =>
      _setAmount(AmountInput.fromPaise(money.paise));

  /// Replaces the amount with pasted text. Returns false (and shakes) when
  /// the text is not a usable amount.
  bool pasteAmount(String raw) {
    final parsed = AmountInput.fromText(raw);
    if (parsed == null) {
      emit(state.copyWith(shakes: state.shakes + 1));
      return false;
    }
    _setAmount(parsed);
    return true;
  }

  void noteChanged(String raw) =>
      emit(state.copyWith(note: TransferNote.sanitise(raw)));

  /// The draft for the review screen, or null when the form is not ready.
  /// Every call mints a new idempotency key: a new confirmation is a new
  /// payment.
  TransferDraft? createDraft() {
    if (!state.canContinue) return null;
    final contact = state.selected!;
    return TransferDraft(
      recipientName: contact.name,
      recipientAccount: contact.vpa,
      amount: state.amount.money,
      idempotencyKey: newIdempotencyKey(),
      note: state.note.isEmpty ? null : state.note,
    );
  }

  /// `transfer-<utc micros>-<8 random hex>`.
  String newIdempotencyKey() {
    final stamp = _clock.now().toUtc().microsecondsSinceEpoch;
    final nonce = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'transfer-$stamp-$nonce';
  }

  void _setAmount(AmountInput next) {
    if (next == state.amount) return;
    final hadError = state.amountError != null;
    final nextState = state.copyWith(amount: next);
    final hasError = nextState.amountError != null;
    emit(
      hasError && !hadError
          ? nextState.copyWith(shakes: state.shakes + 1)
          : nextState,
    );
  }
}
