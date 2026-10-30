import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fin_pay/screens/auth/verification/otp_cubit.dart';
import 'package:fin_pay/screens/auth/verification/otp_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final epoch = DateTime.utc(2026, 10, 31, 12);

  /// Runs [body] inside a FakeAsync zone whose [Clock] follows fake time.
  void fake(void Function(FakeAsync async, OtpCubit cubit) body) {
    fakeAsync((async) {
      final clock = async.getClock(epoch);
      withClock(clock, () {
        final cubit = OtpCubit(expectedCode: '123456', clock: clock);
        body(async, cubit);
        unawaited(cubit.close());
        async.flushTimers();
      });
    }, initialTime: epoch);
  }

  test('starts with a full 30 s cooldown that ticks down to zero', () {
    fake((async, cubit) {
      expect(cubit.state.resendRemaining, const Duration(seconds: 30));
      expect(cubit.state.canResend, isFalse);
      async.elapse(const Duration(seconds: 10));
      expect(cubit.state.resendRemaining, const Duration(seconds: 20));
      expect(cubit.state.resendProgress, closeTo(2 / 3, 0.01));
      async.elapse(const Duration(seconds: 20));
      expect(cubit.state.resendRemaining, Duration.zero);
      expect(cubit.state.canResend, isTrue);
      expect(cubit.isCounting, isFalse);
    });
  });

  test('a clock jump forward ends the countdown, a jump back caps it', () {
    fakeAsync((async) {
      var offset = Duration.zero;
      final base = async.getClock(epoch);
      final clock = Clock(() => base.now().add(offset));
      final cubit = OtpCubit(expectedCode: '123456', clock: clock);
      async.elapse(const Duration(seconds: 5));
      offset = const Duration(hours: 2);
      async.elapse(const Duration(seconds: 1));
      expect(cubit.state.resendRemaining, Duration.zero);
      expect(cubit.state.canResend, isTrue);
      cubit.resend();
      expect(cubit.state.resendRemaining, const Duration(seconds: 30));
      offset = const Duration(hours: -5);
      async.elapse(const Duration(seconds: 1));
      // Never more than the cooldown, and the ticker keeps going.
      expect(
        cubit.state.resendRemaining,
        lessThanOrEqualTo(const Duration(seconds: 30)),
      );
      expect(cubit.isCounting, isTrue);
      unawaited(cubit.close());
      async.flushTimers();
    }, initialTime: epoch);
  });

  test('resend before the cooldown ends is ignored', () {
    fake((async, cubit) {
      cubit.resend();
      expect(cubit.state.resends, 0);
      async.elapse(const Duration(seconds: 30));
      cubit.resend();
      expect(cubit.state.resends, 1);
      expect(cubit.state.resendRemaining, const Duration(seconds: 30));
      expect(cubit.isCounting, isTrue);
    });
  });

  blocTest<OtpCubit, OtpState>(
    'input and backspace drive the digits',
    build: () => OtpCubit(expectedCode: '123456'),
    act: (c) {
      c
        ..input('12')
        ..input('123')
        ..backspace();
    },
    expect: () => const [
      OtpState(digits: '12'),
      OtpState(digits: '123'),
      OtpState(digits: '12'),
    ],
  );

  blocTest<OtpCubit, OtpState>(
    'submit with the right code verifies and emits a success effect',
    build: () => OtpCubit(expectedCode: '123456'),
    act: (c) async {
      c.input('123456');
      await c.submit();
    },
    expect: () => const [
      OtpState(digits: '123456'),
      OtpState(digits: '123456', phase: OtpPhase.verifying),
      OtpState(digits: '123456', phase: OtpPhase.verified),
    ],
  );

  blocTest<OtpCubit, OtpState>(
    'submit with a wrong code counts an attempt and clears',
    build: () => OtpCubit(expectedCode: '123456'),
    act: (c) async {
      c.input('654321');
      await c.submit();
    },
    expect: () => const [
      OtpState(digits: '654321'),
      OtpState(digits: '654321', phase: OtpPhase.verifying),
      OtpState(attempts: 1, phase: OtpPhase.wrong),
    ],
  );

  blocTest<OtpCubit, OtpState>(
    'submit on an incomplete code does nothing',
    build: () => OtpCubit(expectedCode: '123456'),
    act: (c) async {
      c.input('12');
      await c.submit();
    },
    expect: () => const [OtpState(digits: '12')],
  );

  blocTest<OtpCubit, OtpState>(
    'auto-submits when the sixth digit arrives if asked',
    build: () => OtpCubit(expectedCode: '123456', autoSubmit: true),
    act: (c) => c.input('123456'),
    wait: const Duration(milliseconds: 10),
    expect: () => const [
      OtpState(digits: '123456'),
      OtpState(digits: '123456', phase: OtpPhase.verifying),
      OtpState(digits: '123456', phase: OtpPhase.verified),
    ],
  );

  blocTest<OtpCubit, OtpState>(
    'five wrong codes lock the flow and further submits are ignored',
    build: () => OtpCubit(expectedCode: '123456'),
    act: (c) async {
      for (var i = 0; i < 7; i++) {
        c.input('000000');
        await c.submit();
      }
    },
    verify: (c) {
      expect(c.state.phase, OtpPhase.locked);
      expect(c.state.attempts, OtpState.maxAttempts);
    },
  );

  test('concurrent submits verify once', () async {
    final cubit = OtpCubit(expectedCode: '123456')..input('123456');
    await Future.wait([cubit.submit(), cubit.submit(), cubit.submit()]);
    expect(cubit.state.phase, OtpPhase.verified);
    await cubit.close();
  });

  test('the expected code is never part of the state', () {
    final cubit = OtpCubit(expectedCode: '123456');
    expect(cubit.state.toString(), isNot(contains('123456')));
    expect(cubit.state.props, isNot(contains('123456')));
    unawaited(cubit.close());
  });
}
