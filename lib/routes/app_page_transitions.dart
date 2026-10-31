import 'package:fin_pay/design_system/motion/fp_page_transitions.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds the transition for a route's page.
typedef PageTransitionBuilder =
    Page<T> Function<T>({required GoRouterState state, required Widget child});

/// Pluggable page transitions for the router.
///
/// Routes only ever call [page], so swapping [builder] changes every
/// screen. The default, [fp], maps each route to a design-system
/// transition ([kinds]), one entry per route so nothing falls back by
/// accident:
///
/// * shared-axis X for the steps of a flow (onboarding → login → sign-up →
///   OTP → biometrics; transfer → review);
/// * shared-axis Y for the add-card form, which rises like a sheet;
/// * shared-axis Z for drill-in lists pushed over home (history,
///   notifications);
/// * fade-through for root switches and results (splash, the tab shell,
///   card details behind a Hero, payment success, the gallery).
///
/// [fade] is the plain F1 cross-fade, kept for tests.
abstract final class AppPageTransitions {
  /// The active builder. Tests may set it to [fade] or a spy.
  static PageTransitionBuilder builder = fp;

  /// Duration of the plain fade.
  static const Duration fadeDuration = FpMotion.standard;

  /// Transition per route. Every path in [AppRoutes.all] has an entry (a
  /// test enforces it); [defaultKind] only covers unknown paths.
  static const Map<String, FpTransitionKind> kinds = {
    // Splash and root switches.
    AppRoutes.welcome: FpTransitionKind.fadeThrough,
    AppRoutes.home: FpTransitionKind.fadeThrough,
    AppRoutes.statistics: FpTransitionKind.fadeThrough,
    AppRoutes.cards: FpTransitionKind.fadeThrough,
    AppRoutes.profile: FpTransitionKind.fadeThrough,
    AppRoutes.gallery: FpTransitionKind.fadeThrough,
    // Onboarding and auth steps.
    AppRoutes.onboarding: FpTransitionKind.sharedAxisX,
    AppRoutes.login: FpTransitionKind.sharedAxisX,
    AppRoutes.createAccount: FpTransitionKind.sharedAxisX,
    AppRoutes.verification: FpTransitionKind.sharedAxisX,
    AppRoutes.fingerprintSetup: FpTransitionKind.sharedAxisX,
    AppRoutes.passwordReset: FpTransitionKind.sharedAxisX,
    // Payment flow: steps slide, the result fades through.
    AppRoutes.transfer: FpTransitionKind.sharedAxisX,
    AppRoutes.transferReview: FpTransitionKind.sharedAxisX,
    AppRoutes.transferSuccess: FpTransitionKind.fadeThrough,
    // Cards: the form rises like a sheet; details sit behind a Hero.
    AppRoutes.addCard: FpTransitionKind.sharedAxisY,
    AppRoutes.cardDetails: FpTransitionKind.fadeThrough,
    // Drill-in lists pushed over home.
    AppRoutes.transactions: FpTransitionKind.sharedAxisZ,
    AppRoutes.notifications: FpTransitionKind.sharedAxisZ,
  };

  /// Used for paths not listed in [kinds] (the not-found page).
  static const FpTransitionKind defaultKind = FpTransitionKind.fadeThrough;

  /// The transition kind for [path]. Card details carry an id, so the
  /// pattern entry is matched by prefix.
  static FpTransitionKind kindFor(String path) {
    final kind = kinds[path];
    if (kind != null) return kind;
    if (path.startsWith('${AppRoutes.cards}/')) {
      return kinds[AppRoutes.cardDetails]!;
    }
    return defaultKind;
  }

  /// Wraps [child] in the current transition.
  static Page<T> page<T>({
    required GoRouterState state,
    required Widget child,
  }) => builder<T>(state: state, child: child);

  /// Design-system transitions by route (reduce-motion → plain fade inside
  /// `FpPageTransitions`).
  static Page<T> fp<T>({required GoRouterState state, required Widget child}) {
    final path = state.uri.path;
    final name = state.name ?? path;
    return switch (kindFor(path)) {
      FpTransitionKind.sharedAxisX => FpPageTransitions.sharedAxisX<T>(
        child,
        key: state.pageKey,
        name: name,
      ),
      FpTransitionKind.sharedAxisY => FpPageTransitions.sharedAxisY<T>(
        child,
        key: state.pageKey,
        name: name,
      ),
      FpTransitionKind.sharedAxisZ => FpPageTransitions.sharedAxisZ<T>(
        child,
        key: state.pageKey,
        name: name,
      ),
      FpTransitionKind.fadeThrough => FpPageTransitions.fadeThrough<T>(
        child,
        key: state.pageKey,
        name: name,
      ),
    };
  }

  /// A simple cross-fade that becomes a cut under reduce-motion.
  static Page<T> fade<T>({
    required GoRouterState state,
    required Widget child,
  }) => CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name ?? state.uri.path,
    child: child,
    transitionDuration: fadeDuration,
    reverseTransitionDuration: fadeDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: FpMotion.standardDecelerate,
        ),
        child: child,
      );
    },
  );
}
