import 'package:fin_pay/design_system/tokens/fp_colors.dart';
import 'package:fin_pay/design_system/tokens/fp_depth.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:fin_pay/design_system/tokens/fp_typography.dart';
import 'package:flutter/material.dart';

/// Colour slots of the theme. Values default to [FpColors].
@immutable
class FpColorScheme {
  const FpColorScheme({
    this.background = FpColors.background,
    this.surface = FpColors.surface,
    this.surfaceRaised = FpColors.surfaceRaised,
    this.surfaceHigh = FpColors.surfaceHigh,
    this.border = FpColors.border,
    this.borderStrong = FpColors.borderStrong,
    this.popWhite = FpColors.popWhite,
    this.accent = FpColors.accent,
    this.accentDeep = FpColors.accentDeep,
    this.success = FpColors.success,
    this.successDeep = FpColors.successDeep,
    this.alert = FpColors.alert,
    this.alertFill = FpColors.alertFill,
    this.alertDeep = FpColors.alertDeep,
    this.info = FpColors.info,
    this.textPrimary = FpColors.textPrimary,
    this.textSecondary = FpColors.textSecondary,
    this.textTertiary = FpColors.textTertiary,
    this.textDisabled = FpColors.textDisabled,
    this.onPop = FpColors.onPop,
    this.onAlert = FpColors.onAlert,
    this.disabledFace = FpColors.disabledFace,
    this.scrim = FpColors.scrim,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceHigh;
  final Color border;
  final Color borderStrong;
  final Color popWhite;
  final Color accent;
  final Color accentDeep;
  final Color success;
  final Color successDeep;
  final Color alert;
  final Color alertFill;
  final Color alertDeep;
  final Color info;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color onPop;
  final Color onAlert;
  final Color disabledFace;
  final Color scrim;

  /// Every slot by name, for the gallery.
  Map<String, Color> get all => {
    'background': background,
    'surface': surface,
    'surfaceRaised': surfaceRaised,
    'surfaceHigh': surfaceHigh,
    'border': border,
    'borderStrong': borderStrong,
    'popWhite': popWhite,
    'accent': accent,
    'accentDeep': accentDeep,
    'success': success,
    'successDeep': successDeep,
    'alert': alert,
    'alertFill': alertFill,
    'alertDeep': alertDeep,
    'info': info,
    'textPrimary': textPrimary,
    'textSecondary': textSecondary,
    'textTertiary': textTertiary,
    'textDisabled': textDisabled,
    'onPop': onPop,
    'onAlert': onAlert,
    'disabledFace': disabledFace,
    'scrim': scrim,
  };

  FpColorScheme lerp(FpColorScheme other, double t) => FpColorScheme(
    background: Color.lerp(background, other.background, t)!,
    surface: Color.lerp(surface, other.surface, t)!,
    surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
    surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
    border: Color.lerp(border, other.border, t)!,
    borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
    popWhite: Color.lerp(popWhite, other.popWhite, t)!,
    accent: Color.lerp(accent, other.accent, t)!,
    accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
    success: Color.lerp(success, other.success, t)!,
    successDeep: Color.lerp(successDeep, other.successDeep, t)!,
    alert: Color.lerp(alert, other.alert, t)!,
    alertFill: Color.lerp(alertFill, other.alertFill, t)!,
    alertDeep: Color.lerp(alertDeep, other.alertDeep, t)!,
    info: Color.lerp(info, other.info, t)!,
    textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
    textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
    textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
    onPop: Color.lerp(onPop, other.onPop, t)!,
    onAlert: Color.lerp(onAlert, other.onAlert, t)!,
    disabledFace: Color.lerp(disabledFace, other.disabledFace, t)!,
    scrim: Color.lerp(scrim, other.scrim, t)!,
  );
}

/// Typography slots of the theme.
@immutable
class FpTextTheme {
  const FpTextTheme({
    this.displayLarge = FpTypography.displayLarge,
    this.displayMedium = FpTypography.displayMedium,
    this.displaySmall = FpTypography.displaySmall,
    this.displayItalic = FpTypography.displayItalic,
    this.headline = FpTypography.headline,
    this.title = FpTypography.title,
    this.body = FpTypography.body,
    this.bodySmall = FpTypography.bodySmall,
    this.label = FpTypography.label,
    this.overline = FpTypography.overline,
    this.caption = FpTypography.caption,
    this.numeric = FpTypography.numeric,
  });

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle displaySmall;
  final TextStyle displayItalic;
  final TextStyle headline;
  final TextStyle title;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle label;
  final TextStyle overline;
  final TextStyle caption;
  final TextStyle numeric;

  /// Every style by name, for the gallery.
  Map<String, TextStyle> get all => {
    'displayLarge': displayLarge,
    'displayMedium': displayMedium,
    'displaySmall': displaySmall,
    'displayItalic': displayItalic,
    'headline': headline,
    'title': title,
    'body': body,
    'bodySmall': bodySmall,
    'label': label,
    'overline': overline,
    'caption': caption,
    'numeric': numeric,
  };

  FpTextTheme lerp(FpTextTheme other, double t) => FpTextTheme(
    displayLarge: TextStyle.lerp(displayLarge, other.displayLarge, t)!,
    displayMedium: TextStyle.lerp(displayMedium, other.displayMedium, t)!,
    displaySmall: TextStyle.lerp(displaySmall, other.displaySmall, t)!,
    displayItalic: TextStyle.lerp(displayItalic, other.displayItalic, t)!,
    headline: TextStyle.lerp(headline, other.headline, t)!,
    title: TextStyle.lerp(title, other.title, t)!,
    body: TextStyle.lerp(body, other.body, t)!,
    bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
    label: TextStyle.lerp(label, other.label, t)!,
    overline: TextStyle.lerp(overline, other.overline, t)!,
    caption: TextStyle.lerp(caption, other.caption, t)!,
    numeric: TextStyle.lerp(numeric, other.numeric, t)!,
  );
}

/// Spacing, radius and depth slots of the theme.
@immutable
class FpMetrics {
  const FpMetrics({
    this.spaceXs = FpSpacing.xs,
    this.spaceSm = FpSpacing.sm,
    this.spaceMd = FpSpacing.md,
    this.spaceLg = FpSpacing.lg,
    this.spaceXl = FpSpacing.xl,
    this.spaceXxl = FpSpacing.xxl,
    this.spaceXxxl = FpSpacing.xxxl,
    this.radiusXs = FpRadii.xs,
    this.radiusSm = FpRadii.sm,
    this.radiusMd = FpRadii.md,
    this.radiusLg = FpRadii.lg,
    this.depthChip = FpDepth.chip,
    this.depthButton = FpDepth.button,
    this.depthSurface = FpDepth.surface,
    this.depthSheet = FpDepth.sheet,
    this.minTapTarget = FpSpacing.minTapTarget,
  });

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double spaceXxl;
  final double spaceXxxl;
  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double depthChip;
  final double depthButton;
  final double depthSurface;
  final double depthSheet;
  final double minTapTarget;

  FpMetrics lerp(FpMetrics other, double t) => t < 0.5 ? this : other;
}

/// Motion slots of the theme.
@immutable
class FpMotionTokens {
  const FpMotionTokens({
    this.fast = FpMotion.fast,
    this.standard = FpMotion.standard,
    this.emphasized = FpMotion.emphasized,
    this.screen = FpMotion.screen,
    this.enter = FpMotion.emphasizedDecelerate,
    this.exit = FpMotion.emphasizedAccelerate,
    this.change = FpMotion.standardCurve,
  });

  final Duration fast;
  final Duration standard;
  final Duration emphasized;
  final Duration screen;
  final Curve enter;
  final Curve exit;
  final Curve change;

  FpMotionTokens lerp(FpMotionTokens other, double t) => t < 0.5 ? this : other;
}

/// The design tokens as a [ThemeExtension], so `Theme.of(context)` carries
/// them. Read with `context.fp`.
@immutable
class FpTokens extends ThemeExtension<FpTokens> {
  const FpTokens({
    this.colors = const FpColorScheme(),
    this.text = const FpTextTheme(),
    this.metrics = const FpMetrics(),
    this.motion = const FpMotionTokens(),
  });

  /// The default dark tokens.
  static const FpTokens dark = FpTokens();

  final FpColorScheme colors;
  final FpTextTheme text;
  final FpMetrics metrics;
  final FpMotionTokens motion;

  @override
  FpTokens copyWith({
    FpColorScheme? colors,
    FpTextTheme? text,
    FpMetrics? metrics,
    FpMotionTokens? motion,
  }) => FpTokens(
    colors: colors ?? this.colors,
    text: text ?? this.text,
    metrics: metrics ?? this.metrics,
    motion: motion ?? this.motion,
  );

  @override
  FpTokens lerp(ThemeExtension<FpTokens>? other, double t) {
    if (other is! FpTokens) return this;
    return FpTokens(
      colors: colors.lerp(other.colors, t),
      text: text.lerp(other.text, t),
      metrics: metrics.lerp(other.metrics, t),
      motion: motion.lerp(other.motion, t),
    );
  }
}

/// `context.fp` returns the current [FpTokens] (or the dark default when the
/// widget is shown outside an `FpTheme`).
extension FpContext on BuildContext {
  FpTokens get fp => Theme.of(this).extension<FpTokens>() ?? FpTokens.dark;
}
