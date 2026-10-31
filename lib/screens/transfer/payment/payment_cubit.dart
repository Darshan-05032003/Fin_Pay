import 'dart:async';

import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_event.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_event.dart';
import 'package:fin_pay/blocs/transaction/transaction_state.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/domain/payments/payment_gateway.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/transfer/payment/payment_receipt.dart';
import 'package:fin_pay/screens/transfer/transfer/transfer_rules.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where a payment attempt is.
enum PaymentPhase {
  /// Waiting for the swipe.
  idle,

  /// Asking the bank (before the ledger is touched).
  authorizing,

  /// Writing the debit to the ledger (idempotent on the draft's key).
  recording,

  /// Confirming with the bank after the ledger recorded the debit.
  settling,
  success,
  failure;

  bool get isProcessing =>
      this == authorizing || this == recording || this == settling;
}

/// Why an attempt failed and what the user can do about it.
class PaymentFailure extends Equatable {
  const PaymentFailure({
    required this.title,
    required this.message,
    required this.retryable,
    this.canEditAmount = false,
  });

  final String title;
  final String message;

  /// Retrying with the **same** idempotency key makes sense (timeout,
  /// storage error, unreachable bank).
  final bool retryable;

  /// The amount screen is the fix (insufficient balance, invalid draft).
  final bool canEditAmount;

  @override
  List<Object?> get props => [title, message, retryable, canEditAmount];
}

/// Immutable state of one payment. It never carries the draft, the amount
/// or the VPA; the receipt is read from [PaymentCubit.receipt].
class PaymentState extends Equatable {
  const PaymentState({
    this.phase = PaymentPhase.idle,
    this.attempts = 0,
    this.failure,
    this.reference,
  });

  final PaymentPhase phase;

  /// Number of [PaymentCubit.pay] calls that went to the bank.
  final int attempts;
  final PaymentFailure? failure;

  /// Bank reference once [phase] is [PaymentPhase.success].
  final String? reference;

  bool get isProcessing => phase.isProcessing;

  /// Label for the processing overlay.
  String get phaseLabel => switch (phase) {
    PaymentPhase.authorizing => 'Contacting your bank',
    PaymentPhase.recording => 'Recording the payment',
    PaymentPhase.settling => 'Confirming with your bank',
    _ => '',
  };

  @override
  List<Object?> get props => [phase, attempts, failure, reference];

  @override
  String toString() => 'PaymentState(${phase.name})';
}

/// Runs one payment: validate the draft, authorize with the gateway,
/// record the debit through [TransactionBloc] (idempotent on the draft's
/// key), settle with the gateway, then refresh the balance and post a
/// notification. [pay] is re-entrant-safe: while an attempt is in flight,
/// or after success, further calls are ignored. A retry after a failure
/// reuses the same key, so the ledger decides whether the money already
/// moved ("already paid").
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit({
    required TransferDraft draft,
    required PaymentGateway gateway,
    required TransactionBloc transactions,
    NotificationBloc? notifications,
    UserBloc? user,
    Clock? clock,
    this.ledgerTimeout = const Duration(seconds: 10),
  }) : _draft = draft,
       _gateway = gateway,
       _transactions = transactions,
       _notifications = notifications,
       _user = user,
       _clock = clock ?? const Clock(),
       super(const PaymentState());

  final TransferDraft _draft;
  final PaymentGateway _gateway;
  final TransactionBloc _transactions;
  final NotificationBloc? _notifications;
  final UserBloc? _user;
  final Clock _clock;

  /// How long to wait for the ledger's answer.
  final Duration ledgerTimeout;

  PaymentReceipt? _receipt;
  StreamSubscription<TransactionEffect>? _effects;
  bool _inFlight = false;

  /// The payment being made.
  TransferDraft get draft => _draft;

  /// Available once the phase is [PaymentPhase.success].
  PaymentReceipt? get receipt => _receipt;

  /// The ledger row this payment writes (deterministic per key).
  Transaction get transaction => Transaction(
    id: 'tx-${_draft.idempotencyKey}',
    title: 'Sent to ${_draft.recipientName}',
    amount: -_draft.amount,
    date: _clock.now(),
    type: TransactionType.sendMoney,
    icon: 'send',
    recipient: _draft.recipientName,
    idempotencyKey: _draft.idempotencyKey,
  );

  PaymentRequest get _request => PaymentRequest(
    idempotencyKey: _draft.idempotencyKey,
    recipientName: _draft.recipientName,
    recipientVpa: _draft.recipientAccount,
    amount: _draft.amount,
  );

  /// Validates and runs the payment. Ignored while in flight or after
  /// success.
  Future<void> pay() async {
    if (_inFlight || state.phase == PaymentPhase.success || isClosed) return;
    final invalid = _validate();
    if (invalid != null) {
      emit(
        PaymentState(
          phase: PaymentPhase.failure,
          attempts: state.attempts,
          failure: invalid,
        ),
      );
      return;
    }
    _inFlight = true;
    final attempts = state.attempts + 1;
    try {
      emit(PaymentState(phase: PaymentPhase.authorizing, attempts: attempts));
      final authorized = await _call(() => _gateway.authorize(_request));
      if (isClosed) return;
      switch (authorized) {
        case GatewayDeclined(:final reason):
          _fail(
            attempts,
            PaymentFailure(
              title: 'Payment declined',
              message: '$reason Nothing was debited.',
              retryable: false,
            ),
          );
          return;
        case GatewayTimedOut():
          _fail(attempts, _unreachable);
          return;
        case null:
          _fail(attempts, _unreachable);
          return;
        case GatewayApproved():
          break;
      }

      emit(PaymentState(phase: PaymentPhase.recording, attempts: attempts));
      final outcome = await _record();
      if (isClosed) return;
      final bool alreadyPaid;
      switch (outcome) {
        case TransactionAdded():
          alreadyPaid = false;
        case TransactionDuplicate():
          alreadyPaid = true;
        case TransactionRejected(:final reason):
          _fail(
            attempts,
            PaymentFailure(
              title: reason,
              message: reason == 'Insufficient balance'
                  ? 'Your balance does not cover this amount. '
                        'Nothing was debited.'
                  : 'The payment could not be recorded. Nothing was debited.',
              retryable: false,
              canEditAmount: true,
            ),
          );
          return;
        case TransactionFailed():
          _fail(
            attempts,
            const PaymentFailure(
              title: 'Could not save the payment',
              message:
                  'Your money is safe. Retry: the same payment is never '
                  'recorded twice.',
              retryable: true,
            ),
          );
          return;
        case TransactionDeleted():
        case null:
          _fail(
            attempts,
            const PaymentFailure(
              title: 'No answer from the ledger',
              message:
                  'Your money is safe. Retry: the same payment is never '
                  'recorded twice.',
              retryable: true,
            ),
          );
          return;
      }

      emit(PaymentState(phase: PaymentPhase.settling, attempts: attempts));
      final settled = await _call(() => _gateway.settle(_request));
      if (isClosed) return;
      switch (settled) {
        case GatewayApproved(:final reference):
          _receipt = PaymentReceipt(
            draft: _draft,
            reference: reference,
            paidAt: _clock.now().toUtc(),
            alreadyPaid: alreadyPaid,
          );
          emit(
            PaymentState(
              phase: PaymentPhase.success,
              attempts: attempts,
              reference: reference,
            ),
          );
          _afterSuccess(recorded: !alreadyPaid);
        case GatewayTimedOut():
        case null:
          _fail(
            attempts,
            const PaymentFailure(
              title: 'Bank did not confirm',
              message:
                  'The payment was recorded but your bank did not confirm '
                  'in time. Your money is safe. Retry checks with the bank '
                  'before paying again.',
              retryable: true,
            ),
          );
        case GatewayDeclined(:final reason):
          _fail(
            attempts,
            PaymentFailure(
              title: 'Bank could not confirm',
              message: '$reason Retry to check the payment status.',
              retryable: true,
            ),
          );
      }
    } finally {
      _inFlight = false;
    }
  }

  /// Same as [pay]; kept for readability at the call site.
  Future<void> retry() => pay();

  static const PaymentFailure _unreachable = PaymentFailure(
    title: 'Could not reach your bank',
    message: 'Check your connection and retry. Nothing was debited.',
    retryable: true,
  );

  PaymentFailure? _validate() {
    const invalid = PaymentFailure(
      title: 'Invalid payment',
      message:
          'This payment request is not valid. Start again from the '
          'amount screen.',
      retryable: false,
      canEditAmount: true,
    );
    if (_draft.idempotencyKey.trim().isEmpty) return invalid;
    if (_draft.recipientName.trim().isEmpty) return invalid;
    if (_draft.recipientAccount.trim().isEmpty) return invalid;
    if (!_draft.amount.isPositive) return invalid;
    if (_draft.amount > AmountRules.maxPerTransfer) return invalid;
    return null;
  }

  void _fail(int attempts, PaymentFailure failure) {
    if (isClosed) return;
    emit(
      PaymentState(
        phase: PaymentPhase.failure,
        attempts: attempts,
        failure: failure,
      ),
    );
  }

  /// Runs a gateway call; a thrown error reads as "unreachable" (null).
  Future<GatewayResult?> _call(Future<GatewayResult> Function() call) async {
    try {
      return await call();
    } on Object {
      return null;
    }
  }

  /// Dispatches the debit and waits for the matching effect.
  Future<TransactionEffect?> _record() async {
    if (_transactions.isClosed) return null;
    final key = _draft.idempotencyKey;
    final completer = Completer<TransactionEffect?>();
    _cancelEffects();
    _effects = _transactions.effects.listen(
      (effect) {
        final mine = switch (effect) {
          TransactionAdded(:final transaction) ||
          TransactionDuplicate(:final transaction) ||
          TransactionRejected(
            :final transaction,
          ) => transaction.idempotencyKey == key,
          TransactionFailed() => true,
          TransactionDeleted() => false,
        };
        if (mine && !completer.isCompleted) completer.complete(effect);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    _transactions.add(AddTransactionEvent(transaction));
    try {
      return await completer.future.timeout(
        ledgerTimeout,
        onTimeout: () => null,
      );
    } finally {
      _cancelEffects();
    }
  }

  /// Cancels synchronously: the broadcast subscription's cancel future is
  /// the root-zone null future, and awaiting it would schedule the
  /// continuation outside a `fake_async` zone (the timeout test hangs).
  void _cancelEffects() {
    _effects?.cancel().ignore();
    _effects = null;
  }

  void _afterSuccess({required bool recorded}) {
    final user = _user;
    if (user != null && !user.isClosed) user.add(const LoadUserEvent());
    final notifications = _notifications;
    if (recorded && notifications != null && !notifications.isClosed) {
      notifications.add(
        AddNotificationEvent(
          NotificationItem(
            id: 'notify-${_draft.idempotencyKey}',
            title: 'Payment sent',
            message:
                'You paid ${_draft.amount.format()} to ${_draft.recipientName}',
            time: _clock.now(),
            type: NotificationType.paymentRequest,
          ),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _cancelEffects();
    return super.close();
  }
}
