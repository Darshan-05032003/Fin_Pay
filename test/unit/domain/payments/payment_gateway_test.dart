import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/domain/payments/payment_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentRequest _request({
  String vpa = 'priya.r@okaxis',
  String key = 'transfer-1',
  Money amount = const Money.paise(120000),
}) => PaymentRequest(
  idempotencyKey: key,
  recipientName: 'Priya',
  recipientVpa: vpa,
  amount: amount,
);

void main() {
  group('PaymentRequest', () {
    test('is a value type', () {
      expect(_request(), _request());
      expect(_request(), isNot(_request(key: 'transfer-2')));
    });

    test('toString never carries the amount or the VPA', () {
      final text = _request().toString();
      expect(text, isNot(contains('120000')));
      expect(text, isNot(contains('okaxis')));
      expect(text, isNot(contains('Priya')));
    });
  });

  group('SimulatedPaymentGateway', () {
    test('approves an ordinary VPA after the latency, not before', () {
      fakeAsync((async) {
        final gateway = SimulatedPaymentGateway();
        GatewayResult? result;
        unawaited(gateway.authorize(_request()).then((r) => result = r));
        async.elapse(const Duration(milliseconds: 899));
        expect(result, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(result, isA<GatewayApproved>());
      });
    });

    test('the reference is stable per idempotency key and never the key', () {
      fakeAsync((async) {
        final gateway = SimulatedPaymentGateway(latency: Duration.zero);
        GatewayResult? a;
        GatewayResult? b;
        GatewayResult? c;
        unawaited(gateway.authorize(_request()).then((r) => a = r));
        unawaited(gateway.authorize(_request()).then((r) => b = r));
        unawaited(
          gateway.authorize(_request(key: 'transfer-2')).then((r) => c = r),
        );
        async.flushMicrotasks();
        final ra = (a! as GatewayApproved).reference;
        final rb = (b! as GatewayApproved).reference;
        final rc = (c! as GatewayApproved).reference;
        expect(ra, rb);
        expect(ra, isNot(rc));
        expect(ra, startsWith('FP'));
        expect(ra.length, 12);
        expect(ra, isNot(contains('transfer')));
      });
    });

    test('a VPA ending in @fail is declined every time', () {
      fakeAsync((async) {
        final gateway = SimulatedPaymentGateway(latency: Duration.zero);
        final results = <GatewayResult>[];
        for (var i = 0; i < 3; i++) {
          unawaited(
            gateway
                .authorize(_request(vpa: 'test.decline@fail'))
                .then(results.add),
          );
        }
        async.flushMicrotasks();
        expect(results, hasLength(3));
        for (final r in results) {
          expect(r, isA<GatewayDeclined>());
          expect((r as GatewayDeclined).reason, isNotEmpty);
        }
      });
    });

    test('the @fail suffix is matched case-insensitively and only as a '
        'suffix', () {
      fakeAsync((async) {
        final gateway = SimulatedPaymentGateway(latency: Duration.zero);
        GatewayResult? upper;
        GatewayResult? inner;
        unawaited(
          gateway.authorize(_request(vpa: 'x@FAIL')).then((r) => upper = r),
        );
        unawaited(
          gateway
              .authorize(_request(vpa: 'fail@okaxis'))
              .then((r) => inner = r),
        );
        async.flushMicrotasks();
        expect(upper, isA<GatewayDeclined>());
        expect(inner, isA<GatewayApproved>());
      });
    });

    test('settle times out once per key for a @flaky VPA, then approves', () {
      fakeAsync((async) {
        final gateway = SimulatedPaymentGateway(latency: Duration.zero);
        final flaky = _request(vpa: 'test.timeout@flaky');
        final results = <GatewayResult>[];
        unawaited(gateway.authorize(flaky).then(results.add));
        unawaited(gateway.settle(flaky).then(results.add));
        unawaited(gateway.settle(flaky).then(results.add));
        unawaited(
          gateway
              .settle(_request(vpa: 'test.timeout@flaky', key: 'k2'))
              .then(results.add),
        );
        async.flushMicrotasks();
        expect(results[0], isA<GatewayApproved>());
        expect(results[1], isA<GatewayTimedOut>());
        expect(results[2], isA<GatewayApproved>());
        expect(results[3], isA<GatewayTimedOut>());
      });
    });

    test('settle approves ordinary and even @fail VPAs (they never get '
        'there)', () {
      fakeAsync((async) {
        final gateway = SimulatedPaymentGateway(latency: Duration.zero);
        GatewayResult? ok;
        unawaited(gateway.settle(_request()).then((r) => ok = r));
        async.flushMicrotasks();
        expect(ok, isA<GatewayApproved>());
      });
    });

    test('a 100,000-character VPA is handled without blowing up', () {
      fakeAsync((async) {
        final gateway = SimulatedPaymentGateway(latency: Duration.zero);
        GatewayResult? r;
        unawaited(
          gateway
              .authorize(_request(vpa: 'a' * 100000))
              .then((value) => r = value),
        );
        async.flushMicrotasks();
        expect(r, isA<GatewayApproved>());
      });
    });
  });

  group('FakePaymentGateway', () {
    test('approves by default and records every call', () async {
      final fake = FakePaymentGateway();
      expect(await fake.authorize(_request()), isA<GatewayApproved>());
      expect(await fake.settle(_request()), isA<GatewayApproved>());
      expect(fake.authorizeCalls, hasLength(1));
      expect(fake.settleCalls, hasLength(1));
    });

    test('scripted results are consumed in order, then the default', () async {
      final fake = FakePaymentGateway(
        authorizeResults: [const GatewayDeclined('no')],
        settleResults: [const GatewayTimedOut()],
      );
      expect(await fake.authorize(_request()), isA<GatewayDeclined>());
      expect(await fake.authorize(_request()), isA<GatewayApproved>());
      expect(await fake.settle(_request()), isA<GatewayTimedOut>());
      expect(await fake.settle(_request()), isA<GatewayApproved>());
    });

    test('a gate holds every call until released', () {
      fakeAsync((async) {
        final fake = FakePaymentGateway(gated: true);
        GatewayResult? r;
        unawaited(fake.authorize(_request()).then((v) => r = v));
        async.flushMicrotasks();
        expect(r, isNull);
        fake.release();
        async.flushMicrotasks();
        expect(r, isA<GatewayApproved>());
      });
    });

    test('a throwing fake surfaces the error', () {
      final fake = FakePaymentGateway(throwOnAuthorize: true);
      expect(fake.authorize(_request()), throwsA(isA<StateError>()));
    });
  });
}
