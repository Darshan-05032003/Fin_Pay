import 'dart:ui';

import 'package:fin_pay/design_system/tokens/fp_colors.dart';

/// NeoPOP depth: solid bottom/right edge faces instead of blurred shadows.
class FpDepth {
  const FpDepth._();

  /// No edge (ghost controls, flat rows).
  static const double none = 0;

  /// Chips and small controls.
  static const double chip = 2;

  /// Buttons.
  static const double button = 4;

  /// Cards and plunk surfaces.
  static const double surface = 6;

  /// Sheets and the largest surfaces.
  static const double sheet = 8;

  /// The depth values, ascending.
  static const List<double> scale = [none, chip, button, surface, sheet];
}

/// The two edge-face colours for a given face colour.
class FpEdge {
  const FpEdge({required this.right, required this.bottom});

  /// Edge faces for the warm accent.
  static const FpEdge accent = FpEdge(
    right: FpColors.accentDeep,
    bottom: Color(0xFF9E4A14),
  );

  /// Edge faces for neon success.
  static const FpEdge success = FpEdge(
    right: FpColors.successDeep,
    bottom: Color(0xFF6B8A12),
  );

  /// Edge faces for the destructive fill.
  static const FpEdge alert = FpEdge(
    right: FpColors.alertDeep,
    bottom: Color(0xFF55101E),
  );

  /// Edge faces for pop-white faces.
  static const FpEdge popWhite = FpEdge(
    right: Color(0xFFBFC0C6),
    bottom: Color(0xFF8E9098),
  );

  /// Edge faces for dark surfaces (the edge is lighter than the face so it
  /// reads as a lit side).
  static const FpEdge surface = FpEdge(
    right: Color(0xFF2E313A),
    bottom: Color(0xFF3C404B),
  );

  /// Edge faces for raised dark surfaces.
  static const FpEdge surfaceRaised = FpEdge(
    right: Color(0xFF353944),
    bottom: Color(0xFF454A57),
  );

  /// Edge faces for a disabled face.
  static const FpEdge disabled = FpEdge(
    right: Color(0xFF202229),
    bottom: Color(0xFF1A1C21),
  );

  final Color right;
  final Color bottom;
}
