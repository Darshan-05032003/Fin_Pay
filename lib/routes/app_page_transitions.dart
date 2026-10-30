import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Builds the transition for a route's page.
typedef PageTransitionBuilder =
    Page<T> Function<T>({required GoRouterState state, required Widget child});

/// Pluggable page transitions for the router.
///
/// F1 ships a plain fade; the design system (F2) replaces [builder] with
/// shared-axis / fade-through transitions that honour reduce-motion. Routes
/// only ever call [page], so swapping the builder changes every screen.
abstract final class AppPageTransitions {
  /// The active builder. Reset to [fade] in tests.
  static PageTransitionBuilder builder = fade;

  /// Duration of the default fade.
  static const Duration fadeDuration = Duration(milliseconds: 220);

  /// Wraps [child] in the current transition.
  static Page<T> page<T>({
    required GoRouterState state,
    required Widget child,
  }) => builder<T>(state: state, child: child);

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
