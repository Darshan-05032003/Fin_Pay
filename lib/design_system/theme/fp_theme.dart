import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_colors.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:fin_pay/design_system/tokens/fp_typography.dart';
import 'package:flutter/material.dart';

/// Builds the FinPay [ThemeData].
class FpTheme {
  const FpTheme._();

  /// The dark NeoPOP theme. Material widgets that are still used (scaffold,
  /// app bar, dividers, progress indicators) pick up the tokens; design-system
  /// components read [FpTokens] directly.
  static ThemeData dark({FpTokens tokens = FpTokens.dark}) {
    final c = tokens.colors;
    final t = tokens.text;
    final scheme = ColorScheme.dark(
      primary: c.accent,
      onPrimary: c.onPop,
      secondary: c.success,
      onSecondary: c.onPop,
      error: c.alert,
      onError: c.onPop,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceHigh,
      outline: c.border,
    );
    final textTheme = TextTheme(
      displayLarge: t.displayLarge,
      displayMedium: t.displayMedium,
      displaySmall: t.displaySmall,
      headlineMedium: t.headline,
      titleMedium: t.title,
      bodyLarge: t.body,
      bodyMedium: t.body,
      bodySmall: t.bodySmall,
      labelLarge: t.label,
      labelMedium: t.caption,
      labelSmall: t.overline,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      fontFamily: FpTypography.uiFamily,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: t.title,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceHigh,
      ),
      iconTheme: IconThemeData(color: c.textPrimary, size: FpSpacing.xl),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceHigh,
        contentTextStyle: t.body,
        shape: const RoundedRectangleBorder(),
      ),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [tokens],
    );
  }

  /// Static palette for places that cannot read a [BuildContext].
  static const FpColorScheme colors = FpColorScheme();

  /// The default surface colour.
  static const Color surface = FpColors.surface;
}
