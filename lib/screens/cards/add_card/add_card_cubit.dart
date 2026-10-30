import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/screens/cards/add_card/card_validators.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where a submission is.
enum AddCardStatus { idle, submitting, success, failure }

/// Immutable add-card form state. The CVV is **not** part of it: the cubit
/// keeps it in a private field so state logs and `toString` never carry
/// it; only its length is exposed for the live preview.
class AddCardState extends Equatable {
  const AddCardState({
    this.number = '',
    this.name = '',
    this.expiry = '',
    this.cvvLength = 0,
    this.network = CardNetwork.unknown,
    this.numberError,
    this.nameError,
    this.expiryError,
    this.cvvError,
    this.status = AddCardStatus.idle,
    this.submitted = false,
    this.cvvFocused = false,
    this.failures = 0,
    this.message,
    this.addedCardId,
  });

  /// PAN digits typed so far (ASCII digits only, at most 16).
  final String number;

  /// Holder name as typed (upper-cased by the field).
  final String name;

  /// `MM/YY` as typed.
  final String expiry;

  /// Digits of CVV typed so far (never the digits themselves).
  final int cvvLength;
  final CardNetwork network;
  final String? numberError;
  final String? nameError;
  final String? expiryError;
  final String? cvvError;
  final AddCardStatus status;

  /// True after the first submit; validation is live from then on.
  final bool submitted;

  /// The preview flips to the back while the CVV field has focus.
  final bool cvvFocused;

  /// Count of failed submits (changes on every one, so the UI can shake
  /// even when the message is identical).
  final int failures;

  /// Message of the last failure (storage), shown under the form.
  final String? message;

  /// Id of the stored card once [status] is [AddCardStatus.success].
  final String? addedCardId;

  bool get hasErrors =>
      numberError != null ||
      nameError != null ||
      expiryError != null ||
      cvvError != null;

  /// False while a submission is in flight and once one has succeeded (the
  /// form is done; the screen leaves).
  bool get canSubmit =>
      status != AddCardStatus.submitting && status != AddCardStatus.success;

  /// The number as shown on the preview (`4111 11•• •••• ••••`).
  String get previewNumber => CardValidators.previewPan(number);

  AddCardState copyWith({
    String? number,
    String? name,
    String? expiry,
    int? cvvLength,
    CardNetwork? network,
    Object? numberError = _keep,
    Object? nameError = _keep,
    Object? expiryError = _keep,
    Object? cvvError = _keep,
    AddCardStatus? status,
    bool? submitted,
    bool? cvvFocused,
    int? failures,
    Object? message = _keep,
    Object? addedCardId = _keep,
  }) => AddCardState(
    number: number ?? this.number,
    name: name ?? this.name,
    expiry: expiry ?? this.expiry,
    cvvLength: cvvLength ?? this.cvvLength,
    network: network ?? this.network,
    numberError: numberError == _keep
        ? this.numberError
        : numberError as String?,
    nameError: nameError == _keep ? this.nameError : nameError as String?,
    expiryError: expiryError == _keep
        ? this.expiryError
        : expiryError as String?,
    cvvError: cvvError == _keep ? this.cvvError : cvvError as String?,
    status: status ?? this.status,
    submitted: submitted ?? this.submitted,
    cvvFocused: cvvFocused ?? this.cvvFocused,
    failures: failures ?? this.failures,
    message: message == _keep ? this.message : message as String?,
    addedCardId: addedCardId == _keep
        ? this.addedCardId
        : addedCardId as String?,
  );

  static const Object _keep = Object();

  @override
  List<Object?> get props => [
    number,
    name,
    expiry,
    cvvLength,
    network,
    numberError,
    nameError,
    expiryError,
    cvvError,
    status,
    submitted,
    cvvFocused,
    failures,
    message,
    addedCardId,
  ];
}

/// The add-card form: live network detection, Luhn / expiry / CVV
/// validation, duplicate detection against the loaded cards, and a single
/// submission through [CardBloc] (PAN and CVV go to secure storage there).
class AddCardCubit extends Cubit<AddCardState> {
  AddCardCubit({
    required CardBloc cards,
    Clock? clock,
    Random? random,
    this.timeout = const Duration(seconds: 10),
  }) : _cards = cards,
       _clock = clock ?? const Clock(),
       _random = random ?? Random(),
       super(const AddCardState());

  final CardBloc _cards;
  final Clock _clock;
  final Random _random;

  /// How long a submission waits for the bloc before reporting a failure.
  final Duration timeout;

  String _cvv = '';

  /// Message shown when the same card is already in the wallet.
  static const String duplicateMessage = 'This card is already in your wallet';

  void numberChanged(String raw) {
    final digits = CardValidators.digitsOnly(raw);
    emit(
      state.copyWith(
        number: digits,
        network: CardValidators.detectNetwork(digits),
        numberError: state.submitted
            ? CardValidators.validateNumber(digits)
            : null,
      ),
    );
  }

  void nameChanged(String value) {
    final name = value.length > CardValidators.maxNameLength
        ? value.substring(0, CardValidators.maxNameLength)
        : value;
    emit(
      state.copyWith(
        name: name,
        nameError: state.submitted ? CardValidators.validateName(name) : null,
      ),
    );
  }

  void expiryChanged(String value) {
    final expiry = CardValidators.formatExpiry(value);
    emit(
      state.copyWith(
        expiry: expiry,
        expiryError: state.submitted
            ? CardValidators.validateExpiry(expiry, now: _clock.now())
            : null,
      ),
    );
  }

  void cvvChanged(String value) {
    _cvv = CardValidators.digitsOnly(value, max: CardValidators.cvvLength + 1);
    emit(
      state.copyWith(
        cvvLength: _cvv.length,
        cvvError: state.submitted ? CardValidators.validateCvv(_cvv) : null,
      ),
    );
  }

  void cvvFocusChanged({required bool focused}) {
    if (state.cvvFocused != focused) {
      emit(state.copyWith(cvvFocused: focused));
    }
  }

  /// Forces the preview back to the front (the app went to the background).
  void hideBack() => cvvFocusChanged(focused: false);

  /// True when a loaded card shares the last four digits and expiry.
  bool isDuplicate(String digits, String expiry) {
    final current = _cards.state;
    if (current is! CardContent) return false;
    final last4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    return current.cards.any((c) => c.last4 == last4 && c.expireDate == expiry);
  }

  /// Validates, then stores the card once. Repeated calls while one is in
  /// flight do nothing.
  Future<void> submit() async {
    if (!state.canSubmit) return;
    final now = _clock.now();
    final numberError =
        CardValidators.validateNumber(state.number) ??
        (isDuplicate(state.number, state.expiry) ? duplicateMessage : null);
    final nameError = CardValidators.validateName(state.name);
    final expiryError = CardValidators.validateExpiry(state.expiry, now: now);
    final cvvError = CardValidators.validateCvv(_cvv);
    if (numberError != null ||
        nameError != null ||
        expiryError != null ||
        cvvError != null) {
      emit(
        state.copyWith(
          submitted: true,
          numberError: numberError,
          nameError: nameError,
          expiryError: expiryError,
          cvvError: cvvError,
          status: AddCardStatus.failure,
          failures: state.failures + 1,
          message: null,
        ),
      );
      return;
    }
    final card = PaymentCard(
      id: _newId(),
      cardNumber: state.number,
      cardHolderName: state.name.trim().toUpperCase(),
      expireDate: state.expiry,
      cvv: _cvv,
      cardType: state.network.cardType!,
      balance: Money.zero,
    );
    emit(
      state.copyWith(
        submitted: true,
        numberError: null,
        nameError: null,
        expiryError: null,
        cvvError: null,
        status: AddCardStatus.submitting,
        message: null,
      ),
    );
    final effect = await _awaitOutcome(card);
    if (isClosed) return;
    switch (effect) {
      case CardAdded():
        _cvv = '';
        emit(
          state.copyWith(
            status: AddCardStatus.success,
            addedCardId: card.id,
            cvvLength: 0,
          ),
        );
      case CardFailed(:final message):
        emit(
          state.copyWith(
            status: AddCardStatus.failure,
            failures: state.failures + 1,
            message: identical(effect, _unanswered)
                ? 'Could not save the card. Please try again.'
                : message,
          ),
        );
      case CardDeleted():
        break;
    }
  }

  static const CardFailed _unanswered = CardFailed('unanswered');

  /// Dispatches the add and waits for the bloc's answer about this card. A
  /// closed or silent bloc counts as a failure rather than hanging.
  Future<CardEffect> _awaitOutcome(PaymentCard card) async {
    if (_cards.isClosed) return _unanswered;
    final outcome = _cards.effects
        .where(
          (e) => (e is CardAdded && e.card.id == card.id) || e is CardFailed,
        )
        .first
        .timeout(timeout, onTimeout: () => _unanswered)
        .catchError((Object _) => _unanswered);
    _cards.add(AddCardEvent(card));
    return await outcome;
  }

  String _newId() =>
      'card-${_clock.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${_random.nextInt(1 << 30).toRadixString(36)}';

  @override
  Future<void> close() {
    _cvv = '';
    return super.close();
  }
}
