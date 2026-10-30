import 'dart:math' as math;
import 'dart:ui';

/// WCAG 2.1 contrast maths. Used by the token tests and by the gallery.
class FpContrast {
  const FpContrast._();

  /// Minimum ratio for normal text (AA).
  static const double aaNormal = 4.5;

  /// Minimum ratio for large text (≥ 18pt or ≥ 14pt bold) and UI components.
  static const double aaLarge = 3;

  static double _channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  /// Relative luminance per WCAG 2.1.
  static double luminance(Color color) =>
      0.2126 * _channel(color.r) +
      0.7152 * _channel(color.g) +
      0.0722 * _channel(color.b);

  /// Contrast ratio between two opaque colours, always ≥ 1.
  static double ratio(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }
}
