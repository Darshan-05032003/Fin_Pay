import 'package:fin_pay/design_system/motion/fp_page_transitions.dart';
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
/// transition ([kinds]): shared-axis X between the steps of the auth flow,
/// fade-through for the splash, home and everything else. [fade] is the
/// plain F1 cross-fade, kept for tests.
abstract final class AppPageTransitions {
  /// The active builder. Tests may set it to [fade] or a spy.
  static PageTransitionBuilder builder = fp;

  /// Duration of the plain fade.
  static const Duration fadeDuration = Duration(milliseconds: 220);

  /// Transition per route. Anything missing uses [defaultKind].
  static const Map<String, FpTransitionKind> kinds = {
    AppRoutes.welcome: FpTransitionKind.fadeThrough,
    AppRoutes.onboarding: FpTransitionKind.sharedAxisX,
    AppRoutes.login: FpTransitionKind.sharedAxisX,
    AppRoutes.createAccount: FpTransitionKind.sharedAxisX,
    AppRoutes.verification: FpTransitionKind.sharedAxisX,
    AppRoutes.fingerprintSetup: FpTransitionKind.sharedAxisX,
    AppRoutes.passwordReset: FpTransitionKind.sharedAxisX,
    AppRoutes.home: FpTransitionKind.fadeThrough,
  };

  /// Used for routes not listed in [kinds].
  static const FpTransitionKind defaultKind = FpTransitionKind.fadeThrough;

  /// The transition kind for [path].
  static FpTransitionKind kindFor(String path) => kinds[path] ?? defaultKind;

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
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
