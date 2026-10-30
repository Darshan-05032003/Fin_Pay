import 'package:flutter/widgets.dart';

/// The 4/8/12/16/24/32/48 spacing scale.
class FpSpacing {
  const FpSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Every step of the scale, ascending.
  static const List<double> scale = [xs, sm, md, lg, xl, xxl, xxxl];

  /// Default horizontal page gutter.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: lg);

  /// Default card padding.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Minimum touch target size (Material and WCAG 2.5.5).
  static const double minTapTarget = 48;
}

/// Corner radii. NeoPOP is sharp: most components use [none] or [sm].
class FpRadii {
  const FpRadii._();

  static const double none = 0;
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double pill = 999;

  static const BorderRadius noneRadius = BorderRadius.zero;
  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
