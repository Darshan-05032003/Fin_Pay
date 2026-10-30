import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/routes/app_page_transitions.dart';
import 'package:fin_pay/routes/app_redirect.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/routes/go_router_refresh_stream.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/auth/create_account_screen.dart';
import 'package:fin_pay/screens/auth/fingerprint_setup_screen.dart';
import 'package:fin_pay/screens/auth/forgot_password_screen.dart';
import 'package:fin_pay/screens/auth/login_screen.dart';
import 'package:fin_pay/screens/auth/verification_screen.dart';
import 'package:fin_pay/screens/cards/add_card_screen.dart';
import 'package:fin_pay/screens/cards/my_cards_screen.dart';
import 'package:fin_pay/screens/home/home_screen.dart';
import 'package:fin_pay/screens/notifications/notifications_screen.dart';
import 'package:fin_pay/screens/onboarding/onboarding_screen.dart';
import 'package:fin_pay/screens/onboarding/welcome_screen.dart';
import 'package:fin_pay/screens/profile/profile_screen.dart';
import 'package:fin_pay/screens/statistics/statistics_screen.dart';
import 'package:fin_pay/screens/transactions/transactions_screen.dart';
import 'package:fin_pay/screens/transfer/transfer_review_screen.dart';
import 'package:fin_pay/screens/transfer/transfer_screen.dart';
import 'package:fin_pay/screens/transfer/transfer_success_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds the app's [GoRouter].
abstract final class AppRouter {
  /// Creates the router. [session] drives the auth redirect; [gallery]
  /// supplies the debug-only widget gallery (null → placeholder);
  /// [isDebug] defaults to [kDebugMode] and is overridable for tests.
  static GoRouter build({
    required SessionCubit session,
    WidgetBuilder? gallery,
    bool? isDebug,
    String initialLocation = AppRoutes.welcome,
  }) {
    final debug = isDebug ?? kDebugMode;
    return GoRouter(
      initialLocation: initialLocation,
      refreshListenable: GoRouterRefreshStream(session.stream),
      redirect: (context, state) => AppRedirect.resolve(
        location: state.uri.toString(),
        session: session.state,
        isDebug: debug,
      ),
      errorBuilder: (context, state) => _NotFoundScreen(path: state.uri.path),
      routes: [
        _route(AppRoutes.welcome, (_) => const WelcomeScreen()),
        _route(AppRoutes.onboarding, (_) => const OnboardingScreen()),
        _route(AppRoutes.login, (_) => const LoginScreen()),
        _route(AppRoutes.createAccount, (_) => const CreateAccountScreen()),
        _route(AppRoutes.verification, (_) => const VerificationScreen()),
        _route(
          AppRoutes.fingerprintSetup,
          (_) => const FingerprintSetupScreen(),
        ),
        _route(AppRoutes.passwordReset, (_) => const ForgotPasswordScreen()),
        _route(AppRoutes.home, (_) => const HomeScreen()),
        _route(AppRoutes.transactions, (_) => const TransactionsScreen()),
        _route(AppRoutes.transfer, (_) => const TransferScreen()),
        GoRoute(
          path: AppRoutes.transferReview,
          pageBuilder: (context, state) => AppPageTransitions.page(
            state: state,
            child: switch (state.extra) {
              final TransferDraft draft => TransferReviewScreen(draft: draft),
              _ => const _MissingDraftScreen(),
            },
          ),
        ),
        GoRoute(
          path: AppRoutes.transferSuccess,
          pageBuilder: (context, state) => AppPageTransitions.page(
            state: state,
            child: switch (state.extra) {
              final TransferDraft draft => TransferSuccessScreen(draft: draft),
              _ => const _MissingDraftScreen(),
            },
          ),
        ),
        _route(AppRoutes.cards, (_) => const MyCardsScreen()),
        _route(AppRoutes.addCard, (_) => const AddCardScreen()),
        _route(AppRoutes.profile, (_) => const ProfileScreen()),
        _route(AppRoutes.statistics, (_) => const StatisticsScreen()),
        _route(AppRoutes.notifications, (_) => const NotificationsScreen()),
        _route(
          AppRoutes.gallery,
          gallery ?? (_) => const _GalleryPlaceholder(),
        ),
      ],
    );
  }

  static GoRoute _route(String path, WidgetBuilder builder) => GoRoute(
    path: path,
    pageBuilder: (context, state) =>
        AppPageTransitions.page(state: state, child: builder(context)),
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('No route defined for $path')));
}

class _MissingDraftScreen extends StatelessWidget {
  const _MissingDraftScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Start a transfer from the home screen.')),
  );
}

class _GalleryPlaceholder extends StatelessWidget {
  const _GalleryPlaceholder();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Widget gallery (F2)')));
}
