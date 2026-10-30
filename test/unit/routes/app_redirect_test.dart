import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/domain/auth/auth_failure.dart';
import 'package:fin_pay/routes/app_redirect.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const signedIn = SessionAuthenticated('u1');
  const signedOut = SessionUnauthenticated();
  const failed = SessionUnauthenticated(
    failure: InvalidCredentials(remainingAttempts: 2),
  );
  const authenticating = SessionAuthenticating();
  const unknown = SessionUnknown();

  String? go(String path, SessionState s, {bool isDebug = true}) =>
      AppRedirect.resolve(location: path, session: s, isDebug: isDebug);

  group('AppRedirect matrix', () {
    test('every known route is classified exactly once', () {
      for (final path in AppRoutes.all) {
        final memberships = [
          AppRoutes.guestOnly.contains(path),
          AppRoutes.neutral.contains(path),
          AppRoutes.protected.contains(path),
          path == AppRoutes.gallery,
        ].where((m) => m).length;
        expect(memberships, 1, reason: path);
      }
      expect(AppRoutes.tabs.every(AppRoutes.protected.contains), isTrue);
    });

    for (final path in AppRoutes.protected) {
      test('$path: signed out → login, signed in → stays', () {
        expect(go(path, signedOut), AppRoutes.login);
        expect(go(path, failed), AppRoutes.login);
        expect(go(path, authenticating), AppRoutes.login);
        expect(go(path, signedIn), isNull);
      });
    }

    for (final path in AppRoutes.guestOnly) {
      test('$path: signed in → home, signed out → stays', () {
        expect(go(path, signedIn), AppRoutes.home);
        expect(go(path, signedOut), isNull);
        expect(go(path, failed), isNull);
        expect(go(path, authenticating), isNull);
      });
    }

    for (final path in AppRoutes.neutral) {
      test('$path: reachable in both states', () {
        expect(go(path, signedIn), isNull);
        expect(go(path, signedOut), isNull);
      });
    }

    test('unknown session: only the welcome splash is allowed', () {
      expect(go(AppRoutes.welcome, unknown), isNull);
      for (final path in AppRoutes.all.where((p) => p != AppRoutes.welcome)) {
        expect(go(path, unknown), AppRoutes.welcome, reason: path);
      }
    });

    test('card details and add card (under /cards/) need a session', () {
      for (final path in ['/cards/c1', '/cards/add', '/cards/a%20b']) {
        expect(AppRoutes.isProtected(path), isTrue, reason: path);
        expect(go(path, signedOut), AppRoutes.login, reason: path);
        expect(go(path, authenticating), AppRoutes.login, reason: path);
        expect(go(path, signedIn), isNull, reason: path);
        expect(go(path, unknown), AppRoutes.welcome, reason: path);
      }
      expect(AppRoutes.isProtected('/cardsx'), isFalse);
      expect(AppRoutes.isProtected(AppRoutes.login), isFalse);
      expect(AppRoutes.cardDetailsFor('a b/c'), '/cards/a%20b%2Fc');
    });

    test('gallery is reachable only in debug builds', () {
      expect(go(AppRoutes.gallery, signedIn), isNull);
      expect(go(AppRoutes.gallery, signedOut), isNull);
      expect(go(AppRoutes.gallery, signedIn, isDebug: false), AppRoutes.home);
      expect(go(AppRoutes.gallery, signedOut, isDebug: false), AppRoutes.login);
      expect(go(AppRoutes.gallery, unknown, isDebug: false), AppRoutes.welcome);
    });

    test('onboarding is skipped once it has been seen', () {
      String? seen(String path, SessionState s) => AppRedirect.resolve(
        location: path,
        session: s,
        isDebug: true,
        onboardingSeen: true,
      );
      expect(seen(AppRoutes.onboarding, signedOut), AppRoutes.login);
      expect(seen(AppRoutes.onboarding, failed), AppRoutes.login);
      expect(seen(AppRoutes.onboarding, signedIn), AppRoutes.home);
      expect(seen(AppRoutes.onboarding, unknown), AppRoutes.welcome);
      // Not yet seen: the pages are reachable while signed out.
      expect(go(AppRoutes.onboarding, signedOut), isNull);
      // Every other guest route is unaffected by the flag.
      for (final path in AppRoutes.guestOnly.difference({
        AppRoutes.onboarding,
      })) {
        expect(seen(path, signedOut), isNull, reason: path);
      }
      expect(seen(AppRoutes.login, signedIn), AppRoutes.home);
      expect(seen(AppRoutes.home, signedOut), AppRoutes.login);
    });

    test('query strings and trailing data do not bypass the guard', () {
      expect(go('/home?x=1', signedOut), AppRoutes.login);
      expect(go('/login?next=/home', signedIn), AppRoutes.home);
    });

    test('unknown paths are left to the error page', () {
      expect(go('/nope', signedOut), isNull);
      expect(go('/nope', signedIn), isNull);
      expect(go('/home/evil', signedOut), isNull);
    });
  });
}
