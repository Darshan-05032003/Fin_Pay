@Tags(['stress'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/data/repositories/auth_repository_impl.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/login/login_cubit.dart';
import 'package:fin_pay/screens/auth/verification/otp_machine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../widget/screens/screen_harness.dart';
import 'stress_guard.dart';

class MockUsers extends Mock implements IUserRepository {}

/// F3 load tests. Run with:
///
///   flutter test --tags stress --dart-define=FINPAY_STRESS=true \
///     --concurrency=1 test/stress
///
/// Numbers are printed and recorded in docs/LOAD_TEST_REPORT.md.
void main() {
  if (!stressGuard()) return;

  testWidgets('1,000 rapid taps on the login button authenticate once', (
    tester,
  ) async {
    final h = ScreenHarness();
    await h.init(tester);
    await h.pump(tester, AppRoutes.login);
    await h.settle(tester);
    final gate = Completer<AuthResult>();
    var calls = 0;
    when(
      () => h.auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) {
      calls++;
      return gate.future;
    });
    await typeInto(tester, const ValueKey('login-email'), 'user@finpay.com');
    await typeInto(tester, const ValueKey('login-password'), 'FinPay123');
    final center = tester.getCenter(find.byKey(const ValueKey('login-submit')));
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      await tester.tapAt(center);
    }
    sw.stop();
    await tester.pump();
    gate.complete(AuthSuccess(harnessUser));
    await h.settle(tester);
    debugPrint(
      '[stress] 1000 login taps dispatched in ${sw.elapsedMilliseconds} ms, '
      'signIn calls: $calls',
    );
    expect(calls, 1);
    expect(h.location, AppRoutes.home);
  });

  test('10,000 OTP inputs and pastes with random junk never throw', () {
    final rng = Random(11);
    const alphabet = '0123456789abc 😀\u202E\u0000-+()٣٤日本\n\t<>;\'"%\$\u200B';
    final runes = alphabet.runes.toList();
    var s = const OtpState();
    var maxLen = 0;
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10000; i++) {
      final raw = String.fromCharCodes(
        List.generate(rng.nextInt(64), (_) => runes[rng.nextInt(runes.length)]),
      );
      s = switch (rng.nextInt(6)) {
        0 => OtpMachine.backspace(s),
        1 => OtpMachine.verify(s, '123456'),
        2 => OtpMachine.resend(s),
        _ => OtpMachine.input(s, raw),
      };
      if (s.digits.length > maxLen) maxLen = s.digits.length;
      if (s.phase == OtpPhase.locked) s = const OtpState();
    }
    sw.stop();
    debugPrint(
      '[stress] 10k OTP machine inputs in ${sw.elapsedMilliseconds} ms, '
      'max digits $maxLen',
    );
    expect(maxLen, lessThanOrEqualTo(OtpState.length));
  });

  testWidgets('2,000 junk pastes into FpOtpField keep the value ≤ 6 digits', (
    tester,
  ) async {
    var value = '';
    var maxLen = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: FpTheme.dark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FpOtpField(
              value: value,
              onChanged: (v) {
                if (v.length > maxLen) maxLen = v.length;
                setState(() => value = v);
              },
            ),
          ),
        ),
      ),
    );
    final rng = Random(5);
    const alphabet = '0123456789abc 😀\u202E-+()٣٤\n<>;\'"%';
    final runes = alphabet.runes.toList();
    final sw = Stopwatch()..start();
    for (var i = 0; i < 2000; i++) {
      final raw = String.fromCharCodes(
        List.generate(rng.nextInt(40), (_) => runes[rng.nextInt(runes.length)]),
      );
      await tester.enterText(find.byType(EditableText), raw);
    }
    sw.stop();
    await tester.pump(const Duration(seconds: 1));
    debugPrint(
      '[stress] 2000 FpOtpField pastes in ${sw.elapsedMilliseconds} ms, '
      'max digits $maxLen',
    );
    expect(tester.takeException(), isNull);
    expect(maxLen, lessThanOrEqualTo(6));
  });

  test('1,000 login failures engage the lockout and memory stays flat', () {
    Logger.sink = (_) {};
    fakeAsync((async) {
      final clock = async.getClock(DateTime.utc(2026));
      final storage = FakeSecureStorage();
      final auth = AuthRepositoryImpl(
        storage: storage,
        users: MockUsers(),
        clock: clock,
      );
      // A stored credential, so every unlocked attempt pays for PBKDF2.
      unawaited(
        auth.setCredentials(email: 'user@finpay.com', password: 'Right!pass1'),
      );
      async.flushMicrotasks();
      final session = SessionCubit(
        authenticate: AuthenticateUserUseCase(auth),
        authRepository: auth,
      );
      final cubit = LoginCubit(session: session, clock: clock)
        ..emailChanged('user@finpay.com')
        ..passwordChanged('definitely-wrong');
      var locked = 0;
      var invalid = 0;
      var lockWindows = 0;
      final rssBefore = ProcessInfo.currentRss;
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        unawaited(cubit.submit());
        async.flushMicrotasks();
        switch (cubit.state.failure) {
          case AccountLocked():
            locked++;
            // Every 50th attempt let the 30 s lock expire so hashing resumes.
            if (i % 50 == 49) {
              lockWindows++;
              async.elapse(const Duration(seconds: 31));
            }
          case InvalidCredentials():
            invalid++;
          case _:
            break;
        }
      }
      sw.stop();
      final rssAfter = ProcessInfo.currentRss;
      debugPrint(
        '[stress] 1000 login failures in ${sw.elapsedMilliseconds} ms: '
        'invalid $invalid, locked $locked, lock windows expired $lockWindows, '
        'RSS ${rssBefore >> 20} MB → ${rssAfter >> 20} MB',
      );
      // 4 hashed failures before each of the 20 locks (the last expiry has
      // no attempts after it).
      expect(invalid, 4 * lockWindows);
      expect(locked, 1000 - invalid);
      // The last expiry at i = 999 unlocked the form again.
      expect(cubit.state.canSubmit, isTrue);
      expect(rssAfter - rssBefore, lessThan(64 << 20));
      unawaited(cubit.close());
      unawaited(session.close());
      async.flushTimers();
    });
  });

  test(
    '1,000 wrong passwords through the repository lock after five',
    () async {
      final storage = FakeSecureStorage();
      final users = MockUsers();
      final auth = AuthRepositoryImpl(
        storage: storage,
        users: users,
        clock: Clock.fixed(DateTime.utc(2026)),
      );
      var locked = 0;
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        final result = await auth.signIn(email: 'x@y.com', password: 'p$i');
        if (result case AuthFailed(failure: AccountLocked())) locked++;
      }
      sw.stop();
      debugPrint(
        '[stress] 1000 repository sign-ins in ${sw.elapsedMilliseconds} ms, '
        'locked responses: $locked (hashing stops once locked)',
      );
      expect(locked, 1000 - 4);
    },
  );

  testWidgets('500 onboarding page swings leave no ticker behind', (
    tester,
  ) async {
    final h = ScreenHarness();
    await h.init(tester);
    await h.pump(tester, AppRoutes.onboarding);
    await h.settle(tester);
    final pages = find.byKey(const ValueKey('onboarding-pages'));
    final frameTimes = <int>[];
    final sw = Stopwatch()..start();
    for (var i = 0; i < 500; i++) {
      await tester.fling(pages, Offset(i.isEven ? -300 : 300, 0), 1500);
      for (var f = 0; f < 6; f++) {
        final t = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 16));
        t.stop();
        frameTimes.add(t.elapsedMicroseconds);
      }
    }
    sw.stop();
    await h.settle(tester);
    frameTimes.sort();
    final avg = frameTimes.reduce((a, b) => a + b) / frameTimes.length;
    final p90 = frameTimes[(frameTimes.length * 0.9).floor()];
    final p99 = frameTimes[(frameTimes.length * 0.99).floor()];
    debugPrint(
      '[stress] 500 onboarding swings in ${sw.elapsedMilliseconds} ms, '
      '${frameTimes.length} frames: avg ${(avg / 1000).toStringAsFixed(2)} '
      'ms, p90 ${(p90 / 1000).toStringAsFixed(2)} ms, '
      'p99 ${(p99 / 1000).toStringAsFixed(2)} ms',
    );
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
    debugPrint(
      '[stress] tickers after dispose: '
      '${SchedulerBinding.instance.transientCallbackCount}',
    );
    expect(SchedulerBinding.instance.transientCallbackCount, 0);
  });

  blocTest<LoginCubit, LoginState>(
    'LoginCubit survives 5,000 edits of hostile input',
    build: () {
      final auth = MockAuthRepositoryForStress();
      final session = SessionCubit(
        authenticate: AuthenticateUserUseCase(auth),
        authRepository: auth,
      );
      return LoginCubit(session: session);
    },
    act: (c) {
      final rng = Random(2);
      for (var i = 0; i < 5000; i++) {
        c
          ..emailChanged(
            String.fromCharCodes(
              List.generate(rng.nextInt(300), (_) => rng.nextInt(0x3000)),
            ),
          )
          ..passwordChanged('😀' * rng.nextInt(100));
      }
    },
    verify: (c) => expect(c.state.status, LoginStatus.idle),
  );
}

class MockAuthRepositoryForStress extends Mock implements AuthRepository {}
