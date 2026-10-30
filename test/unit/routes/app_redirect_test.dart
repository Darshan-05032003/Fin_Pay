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

    test('gallery is reachable only in debug builds', () {
      expect(go(AppRoutes.gallery, signedIn), isNull);
      expect(go(AppRoutes.gallery, signedOut), isNull);
      expect(go(AppRoutes.gallery, signedIn, isDebug: false), AppRoutes.home);
      expect(go(AppRoutes.gallery, signedOut, isDebug: false), AppRoutes.login);
      expect(go(AppRoutes.gallery, unknown, isDebug: false), AppRoutes.welcome);
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
