import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/screens/profile/profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSessionCubit extends Mock implements SessionCubit {}

void main() {
  late MockSessionCubit session;

  setUp(() {
    session = MockSessionCubit();
    when(session.signOut).thenAnswer((_) async {});
  });

  ProfileCubit build() => ProfileCubit(session: session);

  blocTest<ProfileCubit, LogoutStatus>(
    'confirm → signing out → signed out, one sign-out call',
    build: build,
    act: (c) async {
      c.startLogout();
      await c.confirmLogout();
    },
    expect: () => [
      LogoutStatus.confirming,
      LogoutStatus.signingOut,
      LogoutStatus.signedOut,
    ],
    verify: (_) => verify(session.signOut).called(1),
  );

  blocTest<ProfileCubit, LogoutStatus>(
    'cancelling the sheet returns to idle without signing out',
    build: build,
    act: (c) => c
      ..startLogout()
      ..cancelLogout(),
    expect: () => [LogoutStatus.confirming, LogoutStatus.idle],
    verify: (_) => verifyNever(session.signOut),
  );

  blocTest<ProfileCubit, LogoutStatus>(
    'three rapid confirms sign out once',
    build: () {
      final gate = Completer<void>();
      when(session.signOut).thenAnswer((_) => gate.future);
      scheduleMicrotask(gate.complete);
      return build();
    },
    act: (c) =>
        Future.wait([c.confirmLogout(), c.confirmLogout(), c.confirmLogout()]),
    expect: () => [LogoutStatus.signingOut, LogoutStatus.signedOut],
    verify: (_) => verify(session.signOut).called(1),
  );

  blocTest<ProfileCubit, LogoutStatus>(
    'a failing sign-out reports failed and can be retried',
    build: () {
      var first = true;
      when(session.signOut).thenAnswer((_) async {
        if (first) {
          first = false;
          throw Exception('storage');
        }
      });
      return build();
    },
    act: (c) async {
      await c.confirmLogout();
      c.cancelLogout();
      await c.confirmLogout();
    },
    expect: () => [
      LogoutStatus.signingOut,
      LogoutStatus.failed,
      LogoutStatus.idle,
      LogoutStatus.signingOut,
      LogoutStatus.signedOut,
    ],
  );

  blocTest<ProfileCubit, LogoutStatus>(
    'startLogout while signing out is ignored; confirm after signed out is '
    'ignored',
    build: () {
      final gate = Completer<void>();
      when(session.signOut).thenAnswer((_) => gate.future);
      scheduleMicrotask(gate.complete);
      return build();
    },
    act: (c) async {
      final pending = c.confirmLogout();
      c.startLogout();
      await pending;
      await c.confirmLogout();
    },
    expect: () => [LogoutStatus.signingOut, LogoutStatus.signedOut],
    verify: (_) => verify(session.signOut).called(1),
  );

  test('a closed cubit does not emit after a late sign-out', () async {
    final gate = Completer<void>();
    when(session.signOut).thenAnswer((_) => gate.future);
    final c = build();
    final pending = c.confirmLogout();
    await c.close();
    gate.complete();
    await pending;
    expect(c.state, LogoutStatus.signingOut);
  });
}
