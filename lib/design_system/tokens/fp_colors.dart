import 'dart:ui';

/// The FinPay dark NeoPOP palette.
///
/// Flat, high-contrast surfaces with solid edge faces. Every text / surface
/// pair listed in [textSurfacePairs] is verified for WCAG AA contrast by
/// `test/design_system/tokens/fp_colors_test.dart`.
class FpColors {
  const FpColors._();

  // Surfaces (darkest to lightest).

  /// Page background: near-black.
  static const Color background = Color(0xFF0B0B0D);

  /// Default card / sheet surface. Visibly lighter than [background].
  static const Color surface = Color(0xFF17181C);

  /// Raised surface (chips, inputs, list rows on a card).
  static const Color surfaceRaised = Color(0xFF1F2127);

  /// Highest surface level (toasts, menus, selected chips).
  static const Color surfaceHigh = Color(0xFF2A2D35);

  /// Hairline border between surfaces.
  static const Color border = Color(0xFF353944);

  /// Strong border (focused input, selected segment).
  static const Color borderStrong = Color(0xFF4A4F5C);

  // Pop colours.

  /// Pop white: primary text and bright faces.
  static const Color popWhite = Color(0xFFF5F5F7);

  /// Warm accent for primary actions and highlights.
  static const Color accent = Color(0xFFFF8A3D);

  /// Darker accent for pressed / edge faces.
  static const Color accentDeep = Color(0xFFC9611E);

  /// Neon success for positive outcomes and "cash" highlights.
  static const Color success = Color(0xFFC8F53A);

  /// Darker success for edge faces.
  static const Color successDeep = Color(0xFF8FB51C);

  /// Pink/red alert for errors and destructive text.
  static const Color alert = Color(0xFFFF5C7A);

  /// Darker alert used as the fill of destructive buttons (white text on it).
  static const Color alertFill = Color(0xFFB3263F);

  /// Darkest alert used for destructive edge faces.
  static const Color alertDeep = Color(0xFF7D1A2C);

  /// Informational blue-grey for neutral toasts.
  static const Color info = Color(0xFF8FB8FF);

  // Semantic text tiers.

  /// Primary text.
  static const Color textPrimary = popWhite;

  /// Secondary text (labels, subtitles).
  static const Color textSecondary = Color(0xFFB4B8C3);

  /// Tertiary text (captions, helper text). Still AA on every surface.
  static const Color textTertiary = Color(0xFF949AA8);

  /// Disabled text. Exempt from contrast requirements (WCAG 1.4.3).
  static const Color textDisabled = Color(0xFF5A5F6D);

  /// Text on [accent], [success] and [popWhite] faces.
  static const Color onPop = Color(0xFF0B0B0D);

  /// Text on [alertFill].
  static const Color onAlert = popWhite;

  /// Disabled button face.
  static const Color disabledFace = Color(0xFF2A2D35);

  /// Scrim behind sheets and dialogs.
  static const Color scrim = Color(0xB30B0B0D);

  /// Every text colour that must pass AA on every dark surface.
  static const Map<String, Color> textColours = {
    'textPrimary': textPrimary,
    'textSecondary': textSecondary,
    'textTertiary': textTertiary,
    'accent': accent,
    'success': success,
    'alert': alert,
    'info': info,
  };

  /// Every dark surface text can be placed on.
  static const Map<String, Color> surfaces = {
    'background': background,
    'surface': surface,
    'surfaceRaised': surfaceRaised,
    'surfaceHigh': surfaceHigh,
  };

  /// Text placed on coloured faces (buttons, chips).
  static const Map<String, (Color, Color)> facePairs = {
    'onPop/accent': (onPop, accent),
    'onPop/success': (onPop, success),
    'onPop/popWhite': (onPop, popWhite),
    'onAlert/alertFill': (onAlert, alertFill),
  };

  /// All (name, foreground, background) tuples the contrast test checks.
  static List<(String, Color, Color)> get textSurfacePairs => [
    for (final text in textColours.entries)
      for (final surface in surfaces.entries)
        ('${text.key} on ${surface.key}', text.value, surface.value),
    for (final face in facePairs.entries)
      (face.key, face.value.$1, face.value.$2),
  ];
}
