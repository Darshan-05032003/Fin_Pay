import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fin_pay/core/auth/demo_credentials.dart';
import 'package:fin_pay/core/auth/password_hasher.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/fakes/fake_secure_storage.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/repositories/auth_repository_impl.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepository extends Mock implements IUserRepository {}

void main() {
  const password = 'FinPay123';
  const email = DemoCredentials.email;
  // A fast hasher for the tests that do not verify the precomputed demo
  // record; the lockout logic is independent of the iteration count.
  const fastHasher = PasswordHasher(iterations: 10);

  late FakeSecureStorage storage;
  late MockUserRepository users;
  late DateTime now;
  late AuthRepositoryImpl repo;

  final demoUser = User(
    id: DemoCredentials.userId,
    fullName: DemoCredentials.fullName,
    email: email,
    balance: DemoCredentials.openingBalance,
    createdAt: DateTime.utc(2026),
  );

  setUpAll(() {
    registerFallbackValue(demoUser);
  });

  setUp(() {
    storage = FakeSecureStorage();
    users = MockUserRepository();
    now = DateTime.utc(2026, 10, 31, 12);
    repo = AuthRepositoryImpl(
      storage: storage,
      users: users,
      hasher: fastHasher,
      clock: Clock(() => now),
    );
    when(
      () => users.getCurrentUser(),
    ).thenAnswer((_) async => Success(demoUser));
    when(
      () => users.saveUser(any()),
    ).thenAnswer((_) async => const Success(null));
  });

  Future<void> seedFast() async {
    await repo.setCredentials(email: email, password: password);
  }

  group('signIn', () {
    test('succeeds with the right password and persists the session', () async {
      await seedFast();
      final result = await repo.signIn(email: email, password: password);
      expect(result, AuthSuccess(demoUser));
      expect(storage.values[AuthRepositoryImpl.sessionKey], demoUser.id);
      expect(await repo.restoreSession(), demoUser.id);
    });

    test('verifies the precomputed demo hash with the real hasher', () async {
      final real = AuthRepositoryImpl(
        storage: storage,
        users: users,
        clock: Clock(() => now),
      );
      expect((await real.ensureDemoAccount()).isSuccess, isTrue);
      final result = await real.signIn(email: email, password: password);
      expect(result, isA<AuthSuccess>());
      final wrong = await real.signIn(email: email, password: 'finpay123');
      expect(wrong, isA<AuthFailed>());
    });

    test('normalises the email (case, whitespace, bidi marks)', () async {
      await seedFast();
      for (final variant in [
        '  USER@FinPay.com ',
        '\u200euser@finpay.com\u200f',
        'User@FINPAY.COM\n',
      ]) {
        final result = await repo.signIn(email: variant, password: password);
        expect(result, isA<AuthSuccess>(), reason: variant);
      }
    });

    test('rejects a wrong password with the remaining attempt count', () async {
      await seedFast();
      final result = await repo.signIn(email: email, password: 'nope');
      expect(
        result,
        const AuthFailed(InvalidCredentials(remainingAttempts: 4)),
      );
      expect(storage.values[AuthRepositoryImpl.sessionKey], isNull);
    });

    test('an unknown email fails the same way as a wrong password', () async {
      await seedFast();
      final unknown = await repo.signIn(
        email: 'nobody@example.com',
        password: password,
      );
      final wrong = await repo.signIn(email: email, password: 'x');
      expect(unknown, isA<AuthFailed>());
      expect(
        (unknown as AuthFailed).failure.runtimeType,
        (wrong as AuthFailed).failure.runtimeType,
      );
      expect(
        (unknown.failure as InvalidCredentials).remainingAttempts,
        (wrong.failure as InvalidCredentials).remainingAttempts,
      );
    });

    test('unicode, emoji, RTL and huge passwords never match', () async {
      await seedFast();
      for (final attempt in ['पासवर्ड', '🔐', '\u202eFinPay123', 'F' * 5000]) {
        final result = await repo.signIn(email: email, password: attempt);
        expect(result, isA<AuthFailed>(), reason: attempt);
      }
    });

    test(
      'a corrupt credential record is a failed sign-in, not a crash',
      () async {
        storage.values[AuthRepositoryImpl.credentialKey(email)] = '{"salt":1}';
        final result = await repo.signIn(email: email, password: password);
        expect(result, isA<AuthFailed>());
        expect((result as AuthFailed).failure, isA<InvalidCredentials>());
        storage.values[AuthRepositoryImpl.credentialKey(email)] = 'not json';
        expect(
          await repo.signIn(email: email, password: password),
          isA<AuthFailed>(),
        );
      },
    );

    test(
      'a storage failure is reported as CredentialStoreUnavailable',
      () async {
        await seedFast();
        storage.failing = true;
        final result = await repo.signIn(email: email, password: password);
        expect(result, isA<AuthFailed>());
        expect(
          (result as AuthFailed).failure,
          isA<CredentialStoreUnavailable>(),
        );
      },
    );

    test(
      'a missing user row after a valid password is a store failure',
      () async {
        await seedFast();
        when(
          () => users.getCurrentUser(),
        ).thenAnswer((_) async => const Success(null));
        final result = await repo.signIn(email: email, password: password);
        expect(
          (result as AuthFailed).failure,
          isA<CredentialStoreUnavailable>(),
        );
        when(
          () => users.getCurrentUser(),
        ).thenAnswer((_) async => const Failure('db down'));
        final dbDown = await repo.signIn(email: email, password: password);
        expect(
          (dbDown as AuthFailed).failure,
          const CredentialStoreUnavailable('db down'),
        );
      },
    );
  });

  group('lockout', () {
    setUp(seedFast);

    Future<AuthResult> fail() => repo.signIn(email: email, password: 'wrong');

    test('locks after 5 failures and reports the remaining time', () async {
      for (var i = 4; i >= 1; i--) {
        final r = await fail();
        expect(r, AuthFailed(InvalidCredentials(remainingAttempts: i)));
      }
      final fifth = await fail();
      expect(fifth, isA<AuthFailed>());
      final locked = (fifth as AuthFailed).failure as AccountLocked;
      expect(locked.until, now.add(const Duration(seconds: 30)));
      expect(locked.remaining, const Duration(seconds: 30));
      expect(locked.message, contains('30 s'));
    });

    test('the right password is refused while locked', () async {
      for (var i = 0; i < 5; i++) {
        await fail();
      }
      now = now.add(const Duration(seconds: 10));
      final result = await repo.signIn(email: email, password: password);
      expect(result, isA<AuthFailed>());
      final locked = (result as AuthFailed).failure as AccountLocked;
      expect(locked.remaining, const Duration(seconds: 20));
    });

    test('the lock expires with the clock and the counter resets', () async {
      for (var i = 0; i < 5; i++) {
        await fail();
      }
      now = now.add(const Duration(seconds: 30));
      final afterExpiry = await fail();
      expect(
        afterExpiry,
        const AuthFailed(InvalidCredentials(remainingAttempts: 4)),
      );
      final success = await repo.signIn(email: email, password: password);
      expect(success, isA<AuthSuccess>());
    });

    test('a success clears the failure counter', () async {
      await fail();
      await fail();
      await repo.signIn(email: email, password: password);
      final next = await fail();
      expect(next, const AuthFailed(InvalidCredentials(remainingAttempts: 4)));
    });

    test(
      'lockout state survives a new repository instance (persisted)',
      () async {
        for (var i = 0; i < 5; i++) {
          await fail();
        }
        final fresh = AuthRepositoryImpl(
          storage: storage,
          users: users,
          hasher: fastHasher,
          clock: Clock(() => now),
        );
        final result = await fresh.signIn(email: email, password: password);
        expect((result as AuthFailed).failure, isA<AccountLocked>());
      },
    );

    test('lockout is per email', () async {
      await repo.setCredentials(email: 'other@x.com', password: 'pw');
      for (var i = 0; i < 5; i++) {
        await fail();
      }
      final other = await repo.signIn(email: 'other@x.com', password: 'pw');
      expect(other, isA<AuthSuccess>());
    });

    test('a corrupt lockout record is ignored', () async {
      storage.values[AuthRepositoryImpl.lockoutKey(email)] = '[1,2]';
      expect(
        await repo.signIn(email: email, password: password),
        isA<AuthSuccess>(),
      );
      storage.values[AuthRepositoryImpl.lockoutKey(email)] = 'garbage';
      expect(
        await repo.signIn(email: email, password: password),
        isA<AuthSuccess>(),
      );
    });

    test('a custom policy is honoured', () async {
      final strict = AuthRepositoryImpl(
        storage: storage,
        users: users,
        hasher: fastHasher,
        clock: Clock(() => now),
        policy: const LockoutPolicy(
          maxAttempts: 2,
          lockDuration: Duration(minutes: 5),
        ),
      );
      await strict.signIn(email: email, password: 'x');
      final r = await strict.signIn(email: email, password: 'x');
      expect(
        ((r as AuthFailed).failure as AccountLocked).remaining,
        const Duration(minutes: 5),
      );
    });
  });

  group('ensureDemoAccount', () {
    test('seeds the precomputed hash and the user row once', () async {
      when(
        () => users.getCurrentUser(),
      ).thenAnswer((_) async => const Success(null));
      expect((await repo.ensureDemoAccount()).isSuccess, isTrue);
      final stored = jsonDecode(
        storage.values[AuthRepositoryImpl.credentialKey(email)]!,
      );
      expect(
        HashedPassword.fromJson(stored as Map<String, dynamic>),
        DemoCredentials.hashed,
      );
      final captured = verify(() => users.saveUser(captureAny())).captured;
      expect(captured, hasLength(1));
      final seeded = captured.single as User;
      expect(seeded.email, email);
      expect(seeded.balance, const Money.paise(5624690));
      expect(seeded.createdAt, now);

      // Second run: nothing is rewritten.
      when(
        () => users.getCurrentUser(),
      ).thenAnswer((_) async => Success(seeded));
      final writesBefore = storage.writes;
      expect((await repo.ensureDemoAccount()).isSuccess, isTrue);
      expect(storage.writes, writesBefore);
      verifyNever(() => users.saveUser(any()));
    });

    test('reports a storage failure', () async {
      storage.failing = true;
      final result = await repo.ensureDemoAccount();
      expect(result.isFailure, isTrue);
    });

    test('propagates a user repository failure', () async {
      when(
        () => users.getCurrentUser(),
      ).thenAnswer((_) async => const Failure('db'));
      expect((await repo.ensureDemoAccount()).isFailure, isTrue);
    });
  });

  group('session', () {
    test('restoreSession is null with no marker, a storage failure or a '
        'missing user', () async {
      expect(await repo.restoreSession(), isNull);
      storage.values[AuthRepositoryImpl.sessionKey] = demoUser.id;
      expect(await repo.restoreSession(), demoUser.id);
      storage.values[AuthRepositoryImpl.sessionKey] = 'someone-else';
      expect(await repo.restoreSession(), isNull);
      storage.values[AuthRepositoryImpl.sessionKey] = demoUser.id;
      when(
        () => users.getCurrentUser(),
      ).thenAnswer((_) async => const Success(null));
      expect(await repo.restoreSession(), isNull);
      storage.failing = true;
      expect(await repo.restoreSession(), isNull);
    });

    test('signOut clears the marker and tolerates storage failure', () async {
      storage.values[AuthRepositoryImpl.sessionKey] = demoUser.id;
      await repo.signOut();
      expect(
        storage.values.containsKey(AuthRepositoryImpl.sessionKey),
        isFalse,
      );
      storage.failing = true;
      await expectLater(repo.signOut(), completes);
    });

    test('setCredentials reports storage failure', () async {
      storage.failing = true;
      final r = await repo.setCredentials(email: email, password: 'x');
      expect(r.isFailure, isTrue);
    });
  });
}
