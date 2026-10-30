import 'dart:math' as math;

import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/widgets.dart';

/// Pure geometry of the collapsing balance header, unit-tested on its own.
///
/// `t` is the collapse fraction from [FpCollapseMath]: 0 fully expanded,
/// 1 docked into the app bar.
abstract final class HomeHeaderMath {
  /// Height of the expanded header below the status bar.
  static const double expandedContent = 204;

  /// Height of the docked bar below the status bar.
  static const double collapsedContent = 64;

  /// Scale of the big balance once docked.
  static const double dockedScale = 0.5;

  /// Top of the greeting row (below the status bar) when expanded.
  static const double greetingTop = FpSpacing.lg;

  /// Top of the "available balance" overline when expanded.
  static const double overlineTop = 92;

  /// Top of the big balance when expanded.
  static const double balanceTop = 116;

  /// Width reserved on the right for the eye toggle.
  static const double eyeSlot = FpSpacing.minTapTarget + FpSpacing.sm;

  /// Total header heights for a given status-bar [topPadding].
  static double expandedHeight(double topPadding) =>
      topPadding + expandedContent;

  static double collapsedHeight(double topPadding) =>
      topPadding + collapsedContent;

  /// Scale of the balance at [t]: 1 expanded, [dockedScale] docked.
  static double balanceScale(double t) =>
      FpCollapseMath.lerp(1, dockedScale, t);

  /// Top of the balance (below the status bar) at [t]: it rises from
  /// [balanceTop] to the vertical centre of the docked bar.
  static double balanceY(double t, {required double balanceHeight}) {
    final docked = (collapsedContent - balanceHeight * dockedScale) / 2;
    return FpCollapseMath.lerp(balanceTop, docked, t);
  }

  /// Horizontal alignment of the balance at [t]: left when expanded,
  /// right (against the eye) when docked. Used for both the `Align` and
  /// the scale origin, so the docked balance stays flush right.
  static Alignment balanceAlignment(double t) =>
      Alignment(FpCollapseMath.lerp(-1, 1, t), 0);

  /// Top of the eye toggle at [t]: beside the overline when expanded,
  /// centred in the docked bar when collapsed.
  static double eyeY(double t) => FpCollapseMath.lerp(
    overlineTop - (FpSpacing.minTapTarget - 20) / 2,
    (collapsedContent - FpSpacing.minTapTarget) / 2,
    t,
  );

  /// Opacity of the greeting, overline and bell: gone by half way.
  static double expandedOnlyOpacity(double t) =>
      FpCollapseMath.fadeOut(t, until: 0.5);

  /// Opacity of the docked title: appears in the second half.
  static double dockedOnlyOpacity(double t) =>
      FpCollapseMath.fadeIn(t, from: 0.5);

  /// Upward drift of the greeting while it fades, in pixels.
  static double greetingShift(double t) => -24 * t.clamp(0.0, 1.0);

  /// Time-of-day greeting.
  static String greetingFor(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  /// First name (or the full name when there is no space).
  static String firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'there';
    final space = trimmed.indexOf(' ');
    return space < 0 ? trimmed : trimmed.substring(0, space);
  }
}

/// Pure tilt of the offers carousel: a card `delta` pages from the centre
/// turns away and shrinks, clamped so far cards do not fold flat.
abstract final class OfferTilt {
  /// Rotation about Y per page of distance, in radians.
  static const double anglePerPage = 0.32;

  /// Scale lost per page of distance.
  static const double scalePerPage = 0.06;

  /// Perspective entry (row 3, column 2).
  static const double perspective = 0.0012;

  static double rotationY(double delta) =>
      -delta.clamp(-1.0, 1.0) * anglePerPage;

  static double scale(double delta) =>
      math.max(0.85, 1 - delta.abs() * scalePerPage);

  /// The transform for [delta]; identity when centred.
  static Matrix4 transform(double delta) {
    if (delta == 0) return Matrix4.identity();
    return Matrix4.identity()
      ..setEntry(3, 2, perspective)
      ..rotateY(rotationY(delta))
      ..scaleByDouble(scale(delta), scale(delta), 1, 1);
  }
}
