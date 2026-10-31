import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/money/money.dart';

/// What the app asks the gateway to move.
///
/// `toString` deliberately prints nothing but the class name: requests pass
/// through `BlocObserver`s and error logs, and neither may carry an amount
/// or a VPA.
class PaymentRequest extends Equatable {
  const PaymentRequest({
    required this.idempotencyKey,
    required this.recipientName,
    required this.recipientVpa,
    required this.amount,
  });

  /// Generated once per confirmation; retries reuse it.
  final String idempotencyKey;
  final String recipientName;
  final String recipientVpa;
  final Money amount;

  @override
  List<Object?> get props => [
    idempotencyKey,
    recipientName,
    recipientVpa,
    amount,
  ];

  @override
  String toString() => 'PaymentRequest';
}

/// The gateway's answer to [PaymentGateway.authorize] / [PaymentGateway.settle].
sealed class GatewayResult extends Equatable {
  const GatewayResult();

  @override
  List<Object?> get props => [];
}

/// The bank accepted. [reference] is the bank-side id shown on the receipt.
final class GatewayApproved extends GatewayResult {
  const GatewayApproved(this.reference);

  final String reference;

  @override
  List<Object?> get props => [reference];
}

/// The bank refused; retrying with the same request fails again.
final class GatewayDeclined extends GatewayResult {
  const GatewayDeclined(this.reason);

  final String reason;

  @override
  List<Object?> get props => [reason];
}

/// No answer in time. The payment may or may not have gone through, so the
/// client must retry with the **same** idempotency key and let the ledger
/// decide.
final class GatewayTimedOut extends GatewayResult {
  const GatewayTimedOut();
}

/// The bank-side half of a payment. Every implementation is asynchronous
/// and may be slow; the app shows a processing state while it waits.
///
/// Two phases: [authorize] before the ledger is touched (a decline costs
/// nothing), [settle] after the ledger has recorded the debit (a timeout
/// here is the classic "debited but unconfirmed" case that idempotent
/// retries exist for).
abstract interface class PaymentGateway {
  /// Asks the bank whether it will take [request].
  Future<GatewayResult> authorize(PaymentRequest request);

  /// Confirms [request] after the ledger has recorded it.
  Future<GatewayResult> settle(PaymentRequest request);
}

/// The demo gateway: nothing leaves the device.
///
/// Rules (documented in `docs/DECISIONS.md` and the README):
/// - a VPA ending in `@fail` is declined by [authorize], every time;
/// - a VPA ending in `@flaky` is authorized, but its first [settle] per
///   idempotency key times out; the retry settles;
/// - everything else is approved.
///
/// [latency] is simulated with a plain [Timer], so `fake_async` and the
/// widget-test clock control it. The reference is a stable hash of the
/// idempotency key (a retry shows the same reference).
class SimulatedPaymentGateway implements PaymentGateway {
  SimulatedPaymentGateway({this.latency = const Duration(milliseconds: 900)});

  /// Round-trip delay per phase.
  final Duration latency;

  /// VPA suffix that is always declined.
  static const String declineSuffix = '@fail';

  /// VPA suffix whose first settlement per key times out.
  static const String flakySuffix = '@flaky';

  final Set<String> _settleAttempted = {};

  static bool _endsWith(String vpa, String suffix) =>
      vpa.toLowerCase().endsWith(suffix);

  /// `FP` + the first ten hex characters of the key's SHA-256.
  static String referenceFor(String idempotencyKey) {
    final digest = sha256.convert(utf8.encode(idempotencyKey)).toString();
    return 'FP${digest.substring(0, 10).toUpperCase()}';
  }

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  @override
  Future<GatewayResult> authorize(PaymentRequest request) async {
    await _wait();
    if (_endsWith(request.recipientVpa, declineSuffix)) {
      return const GatewayDeclined('Your bank declined this payment.');
    }
    return GatewayApproved(referenceFor(request.idempotencyKey));
  }

  @override
  Future<GatewayResult> settle(PaymentRequest request) async {
    await _wait();
    if (_endsWith(request.recipientVpa, flakySuffix) &&
        _settleAttempted.add(request.idempotencyKey)) {
      return const GatewayTimedOut();
    }
    return GatewayApproved(referenceFor(request.idempotencyKey));
  }
}
