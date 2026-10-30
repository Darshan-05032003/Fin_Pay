import 'dart:math' as math;

/// Layout of one card in the stack, as plain numbers (pure, unit-tested).
class CardSlot {
  const CardSlot({
    required this.dx,
    required this.dy,
    required this.scale,
    required this.rotationY,
    required this.visible,
  });

  /// Horizontal offset in pixels from the centred position.
  final double dx;

  /// Vertical offset in pixels from the top of the stack area.
  final double dy;
  final double scale;

  /// Rotation about Y in radians (perspective swipe).
  final double rotationY;

  /// False for cards buried too deep in the pile to draw.
  final bool visible;

  CardSlot lerp(CardSlot other, double t) {
    final k = t.clamp(0.0, 1.0);
    return CardSlot(
      dx: dx + (other.dx - dx) * k,
      dy: dy + (other.dy - dy) * k,
      scale: scale + (other.scale - scale) * k,
      rotationY: rotationY + (other.rotationY - rotationY) * k,
      visible: visible || other.visible,
    );
  }

  @override
  String toString() =>
      'CardSlot(dx: $dx, dy: $dy, scale: $scale, rotY: $rotationY, '
      'visible: $visible)';
}

/// Pure geometry for the CRED-style card stack.
///
/// Collapsed: a pile where the focused card sits on top and every card
/// behind it peeks out below, smaller. Fanned: a horizontal carousel where
/// neighbours sit a page-width away, turned towards the viewer.
abstract final class CardStackMath {
  /// Pixels each buried card peeks out below the one above it.
  static const double peek = 28;

  /// Scale lost per depth level in the pile.
  static const double pileScaleStep = 0.04;

  /// Cards deeper than this are not drawn (they would be hidden anyway).
  static const int maxPileDepth = 4;

  /// Fraction of the width one fanned page occupies.
  static const double viewportFraction = 0.78;

  /// Rotation of a neighbour one page away, in radians.
  static const double fanAngle = 0.42;

  /// Scale lost per page of distance from the focused page.
  static const double fanScaleStep = 0.1;

  /// Card aspect ratio (ISO/IEC 7810 ID-1).
  static const double aspectRatio = 85.6 / 53.98;

  /// Depth of card [index] in a pile whose top card is [focused]: 0 for the
  /// focused card, then the cards after it, wrapping round so the ones
  /// before it are deepest.
  static int depth(int index, int focused, int count) {
    if (count <= 0) return 0;
    return (index - focused + count) % count;
  }

  /// Slot of card [index] in the collapsed pile.
  static CardSlot stacked(int index, int focused, int count) {
    final d = depth(index, focused, count);
    final visible = d < maxPileDepth;
    final shown = math.min(d, maxPileDepth - 1);
    return CardSlot(
      dx: 0,
      dy: shown * peek,
      scale: 1 - shown * pileScaleStep,
      rotationY: 0,
      visible: visible,
    );
  }

  /// Slot of card [index] when the carousel sits at [page] (fractional
  /// while swiping) in a viewport [width] px wide.
  static CardSlot fanned(int index, double page, double width) {
    final delta = index - page;
    final distance = delta.abs();
    return CardSlot(
      dx: delta * width * viewportFraction,
      dy: 0,
      scale: math.max(0.6, 1 - distance * fanScaleStep),
      rotationY: (-delta).clamp(-1.0, 1.0) * fanAngle,
      visible: distance < 2.5,
    );
  }

  /// Height the pile needs for [count] cards of [cardHeight].
  static double pileHeight(int count, double cardHeight) {
    final shown = math.max(0, math.min(count, maxPileDepth) - 1);
    return cardHeight + shown * peek;
  }

  /// Card height for a [width] px wide card.
  static double cardHeight(double width) => width / aspectRatio;

  /// The focused index for a fractional carousel [page].
  static int focusedFor(double page, int count) {
    if (count <= 0) return 0;
    return page.round().clamp(0, count - 1);
  }
}
