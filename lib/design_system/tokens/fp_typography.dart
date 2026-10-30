import 'package:fin_pay/design_system/tokens/fp_colors.dart';
import 'package:flutter/painting.dart';

/// Type scale. Display sizes use Instrument Serif (big amounts, hero
/// headlines); everything else uses Manrope.
class FpTypography {
  const FpTypography._();

  /// Bundled UI family (weights 400 to 800).
  static const String uiFamily = 'Manrope';

  /// Bundled display family (regular and italic).
  static const String displayFamily = 'InstrumentSerif';

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Instrument Serif has no rupee glyph (U+20B9); Manrope supplies it.
  static const List<String> _displayFallback = [uiFamily];

  // Display (Instrument Serif).

  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: _displayFallback,
    fontSize: 56,
    height: 1.05,
    letterSpacing: -0.5,
    color: FpColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: _displayFallback,
    fontSize: 40,
    height: 1.1,
    letterSpacing: -0.25,
    color: FpColors.textPrimary,
    fontFeatures: _tabular,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: _displayFallback,
    fontSize: 32,
    height: 1.15,
    color: FpColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// Italic display accent for editorial moments ("your money, your rules").
  static const TextStyle displayItalic = TextStyle(
    fontFamily: displayFamily,
    fontFamilyFallback: _displayFallback,
    fontStyle: FontStyle.italic,
    fontSize: 32,
    height: 1.15,
    color: FpColors.textPrimary,
  );

  // UI (Manrope).

  static const TextStyle headline = TextStyle(
    fontFamily: uiFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.4,
    color: FpColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontFamily: uiFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
    color: FpColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: uiFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: FpColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: uiFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: FpColors.textSecondary,
  );

  /// Button and chip labels.
  static const TextStyle label = TextStyle(
    fontFamily: uiFamily,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 0.8,
    color: FpColors.textPrimary,
  );

  /// Small uppercase eyebrow labels.
  static const TextStyle overline = TextStyle(
    fontFamily: uiFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.2,
    color: FpColors.textTertiary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: uiFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: FpColors.textTertiary,
  );

  /// Numeric UI text (balances in rows) with tabular figures.
  static const TextStyle numeric = TextStyle(
    fontFamily: uiFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: FpColors.textPrimary,
    fontFeatures: _tabular,
  );

  /// Every style, by name, for the gallery and tests.
  static const Map<String, TextStyle> all = {
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
}
