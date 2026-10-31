import 'dart:async';

import 'package:fin_pay/domain/payments/payment_gateway.dart';

/// Scriptable [PaymentGateway] for tests.
///
/// Results are consumed in order from the scripted authorize / settle lists;
/// when a list runs out the call is approved with [reference]. With
/// [gated] every call waits until [release] is called (processing-state
/// tests). Every request is recorded.
class FakePaymentGateway implements PaymentGateway {
  FakePaymentGateway({
    List<GatewayResult> authorizeResults = const [],
    List<GatewayResult> settleResults = const [],
    this.reference = 'FPTEST000001',
    this.gated = false,
    this.throwOnAuthorize = false,
    this.throwOnSettle = false,
  }) : _authorize = List.of(authorizeResults),
       _settle = List.of(settleResults);

  final List<GatewayResult> _authorize;
  final List<GatewayResult> _settle;

  /// Reference used for default approvals.
  final String reference;

  /// Hold every call until [release].
  final bool gated;
  final bool throwOnAuthorize;
  final bool throwOnSettle;

  /// Requests seen by [authorize], in order.
  final List<PaymentRequest> authorizeCalls = [];

  /// Requests seen by [settle], in order.
  final List<PaymentRequest> settleCalls = [];

  Completer<void> _gate = Completer<void>();

  /// Lets every held call through (and the next ones until [hold]).
  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  /// Holds the calls that follow (after a [release]).
  void hold() {
    if (_gate.isCompleted) _gate = Completer<void>();
  }

  Future<void> _wait() async {
    if (gated) await _gate.future;
  }

  @override
  Future<GatewayResult> authorize(PaymentRequest request) async {
    authorizeCalls.add(request);
    if (throwOnAuthorize) throw StateError('gateway unreachable');
    await _wait();
    return _authorize.isEmpty
        ? GatewayApproved(reference)
        : _authorize.removeAt(0);
  }

  @override
  Future<GatewayResult> settle(PaymentRequest request) async {
    settleCalls.add(request);
    if (throwOnSettle) throw StateError('gateway unreachable');
    await _wait();
    return _settle.isEmpty ? GatewayApproved(reference) : _settle.removeAt(0);
  }
}
