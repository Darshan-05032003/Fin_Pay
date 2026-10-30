import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/screens/auth/forgot_password/forgot_password_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ForgotPasswordCubit build() => ForgotPasswordCubit(delay: Duration.zero);

  blocTest<ForgotPasswordCubit, ForgotPasswordState>(
    'submit validates the email first',
    build: build,
    act: (c) => c.submit(),
    expect: () => const [
      ForgotPasswordState(submitted: true, emailError: 'Email is required'),
    ],
  );

  blocTest<ForgotPasswordCubit, ForgotPasswordState>(
    'a valid email goes submitting → sent',
    build: build,
    act: (c) async {
      c.emailChanged('user@finpay.com');
      await c.submit();
    },
    expect: () => const [
      ForgotPasswordState(email: 'user@finpay.com'),
      ForgotPasswordState(
        email: 'user@finpay.com',
        submitted: true,
        status: ForgotPasswordStatus.submitting,
      ),
      ForgotPasswordState(
        email: 'user@finpay.com',
        submitted: true,
        status: ForgotPasswordStatus.sent,
      ),
    ],
  );

  blocTest<ForgotPasswordCubit, ForgotPasswordState>(
    'errors go live after the first submit and clear when fixed',
    build: build,
    act: (c) {
      c.emailChanged('bad');
      unawaited(c.submit());
      c.emailChanged('user@finpay.com');
    },
    expect: () => const [
      ForgotPasswordState(email: 'bad'),
      ForgotPasswordState(
        email: 'bad',
        submitted: true,
        emailError: 'Enter a valid email address',
      ),
      ForgotPasswordState(email: 'user@finpay.com', submitted: true),
    ],
  );

  test(
    'unknown and known addresses behave identically (no enumeration)',
    () async {
      final a = build()..emailChanged('nobody@example.com');
      await a.submit();
      final b = build()..emailChanged('user@finpay.com');
      await b.submit();
      expect(a.state.status, ForgotPasswordStatus.sent);
      expect(b.state.status, ForgotPasswordStatus.sent);
      await a.close();
      await b.close();
    },
  );

  test('concurrent submits send once and reset returns to idle', () async {
    final cubit = build()..emailChanged('user@finpay.com');
    await Future.wait([cubit.submit(), cubit.submit()]);
    expect(cubit.sends, 1);
    cubit.reset();
    expect(cubit.state.status, ForgotPasswordStatus.idle);
    expect(cubit.state.email, 'user@finpay.com');
    await cubit.close();
  });
}
