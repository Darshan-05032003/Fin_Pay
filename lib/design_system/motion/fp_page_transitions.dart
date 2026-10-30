import 'package:animations/animations.dart';
import 'package:fin_pay/design_system/tokens/fp_colors.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The kinds of screen transition in the motion vocabulary.
enum FpTransitionKind { sharedAxisX, sharedAxisY, sharedAxisZ, fadeThrough }

/// go_router page builders for the shared-axis and fade-through transitions
/// (built on `package:animations`). Replaces `CredPageTransition`,
/// `ScalePageRoute` and `SlidePageRoute`.
///
/// Rules: lateral navigation (tabs, steps) uses shared-axis X, hierarchical
/// detail uses Y or Z, and unrelated destinations use fade-through. Every
/// builder degrades to a plain fade with reduced motion.
class FpPageTransitions {
  const FpPageTransitions._();

  /// Steps in a flow (onboarding, transfer → review → result).
  static CustomTransitionPage<T> sharedAxisX<T>(
    Widget child, {
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
  }) => _page(
    child,
    FpTransitionKind.sharedAxisX,
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
  );

  /// Parent → child detail (home → card details).
  static CustomTransitionPage<T> sharedAxisY<T>(
    Widget child, {
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
  }) => _page(
    child,
    FpTransitionKind.sharedAxisY,
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
  );

  /// Zoom into a detail or modal flow.
  static CustomTransitionPage<T> sharedAxisZ<T>(
    Widget child, {
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
  }) => _page(
    child,
    FpTransitionKind.sharedAxisZ,
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
  );

  /// Unrelated destinations (bottom tabs, splash → home).
  static CustomTransitionPage<T> fadeThrough<T>(
    Widget child, {
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
  }) => _page(
    child,
    FpTransitionKind.fadeThrough,
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
  );

  /// Builds the transition widget for [kind]. Exposed so route tests can
  /// assert the widget type.
  static Widget buildTransition(
    BuildContext context,
    FpTransitionKind kind,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (FpMotion.of(context).reduce) {
      return FadeTransition(opacity: animation, child: child);
    }
    const fill = FpColors.background;
    return switch (kind) {
      FpTransitionKind.sharedAxisX => SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: fill,
        child: child,
      ),
      FpTransitionKind.sharedAxisY => SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.vertical,
        fillColor: fill,
        child: child,
      ),
      FpTransitionKind.sharedAxisZ => SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.scaled,
        fillColor: fill,
        child: child,
      ),
      FpTransitionKind.fadeThrough => FadeThroughTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        fillColor: fill,
        child: child,
      ),
    };
  }

  static CustomTransitionPage<T> _page<T>(
    Widget child,
    FpTransitionKind kind, {
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
  }) => CustomTransitionPage<T>(
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    transitionDuration: FpMotion.screen,
    reverseTransitionDuration: FpMotion.emphasized,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        buildTransition(context, kind, animation, secondaryAnimation, child),
    child: child,
  );
}
