import 'dart:math' as math;

import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// The parallax maths of the onboarding illustrations, pure for tests.
abstract final class OnboardingParallax {
  /// Relative speeds of the back, middle and front layers (1 = moves with
  /// the page content).
  static const List<double> speeds = [0.35, 0.6, 0.85];

  /// Extra horizontal translation for a layer with [speed], given how far
  /// the viewport is from the layer's page ([delta] = `page - index`, in
  /// pages, clamped to ±1). A layer slower than the content counter-shifts
  /// towards the viewport, so it appears to lag behind while swiping.
  static double layerShift(
    double delta, {
    required double width,
    required double speed,
  }) {
    final d = delta.clamp(-1.0, 1.0);
    return d * width * (1 - speed);
  }
}

/// Which code-drawn shape a layer paints.
enum OnboardingGlyph { card, coin, arrow, bars, ring, spark, shield, lock, key }

/// One illustration layer: a glyph with its speed and colour role.
class OnboardingLayer {
  const OnboardingLayer(this.glyph, {required this.speed});

  final OnboardingGlyph glyph;
  final double speed;
}

/// Copy and illustration of one onboarding page.
class OnboardingPageSpec {
  const OnboardingPageSpec({
    required this.title,
    required this.body,
    required this.layers,
    required this.semanticLabel,
  });

  final String title;
  final String body;
  final List<OnboardingLayer> layers;

  /// Description of the illustration for screen readers.
  final String semanticLabel;

  static const List<OnboardingPageSpec> all = [
    OnboardingPageSpec(
      title: 'Pay anyone, instantly',
      body:
          'Send money to a contact or a UPI ID in two taps. '
          'Every payment is confirmed with a swipe, never a double tap.',
      semanticLabel: 'A payment card, a coin and an arrow leaving the card',
      layers: [
        OnboardingLayer(OnboardingGlyph.card, speed: 0.35),
        OnboardingLayer(OnboardingGlyph.coin, speed: 0.6),
        OnboardingLayer(OnboardingGlyph.arrow, speed: 0.85),
      ],
    ),
    OnboardingPageSpec(
      title: 'See where it goes',
      body:
          'Spending by week, month and year, grouped the way you think '
          'about it. No spreadsheets, no surprises.',
      semanticLabel: 'A bar chart, a progress ring and a spark',
      layers: [
        OnboardingLayer(OnboardingGlyph.bars, speed: 0.35),
        OnboardingLayer(OnboardingGlyph.ring, speed: 0.6),
        OnboardingLayer(OnboardingGlyph.spark, speed: 0.85),
      ],
    ),
    OnboardingPageSpec(
      title: 'Locked to you',
      body:
          'Your fingerprint opens the app, the screen hides in the app '
          'switcher, and nothing sensitive is stored in the clear.',
      semanticLabel: 'A shield, a padlock and a key',
      layers: [
        OnboardingLayer(OnboardingGlyph.shield, speed: 0.35),
        OnboardingLayer(OnboardingGlyph.lock, speed: 0.6),
        OnboardingLayer(OnboardingGlyph.key, speed: 0.85),
      ],
    ),
  ];
}

/// A square, code-drawn, three-layer illustration whose layers move at
/// different speeds while the [controller] scrolls. Static (no parallax)
/// with reduced motion.
class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({
    required this.spec,
    required this.index,
    required this.controller,
    super.key,
    this.size = 240,
  });

  final OnboardingPageSpec spec;
  final int index;
  final PageController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.fp.colors;
    final reduce = FpMotion.of(context).reduce;
    return Semantics(
      label: spec.semanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final page = _page();
                final delta = page - index;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final layer in spec.layers)
                      Transform.translate(
                        offset: Offset(
                          reduce
                              ? 0
                              : OnboardingParallax.layerShift(
                                  delta,
                                  width: size,
                                  speed: layer.speed,
                                ),
                          0,
                        ),
                        child: CustomPaint(
                          painter: OnboardingGlyphPainter(
                            glyph: layer.glyph,
                            face: _faceFor(layer.glyph, c),
                            edge: _edgeFor(layer.glyph, c),
                            outline: c.border,
                            ink: c.onPop,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _page() {
    if (!controller.hasClients) return controller.initialPage.toDouble();
    final position = controller.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return controller.initialPage.toDouble();
    }
    return controller.page ?? controller.initialPage.toDouble();
  }

  static Color _faceFor(OnboardingGlyph g, FpColorScheme c) => switch (g) {
    OnboardingGlyph.card ||
    OnboardingGlyph.bars ||
    OnboardingGlyph.shield => c.surfaceHigh,
    OnboardingGlyph.coin ||
    OnboardingGlyph.ring ||
    OnboardingGlyph.lock => c.accent,
    OnboardingGlyph.arrow ||
    OnboardingGlyph.spark ||
    OnboardingGlyph.key => c.success,
  };

  static Color _edgeFor(OnboardingGlyph g, FpColorScheme c) => switch (g) {
    OnboardingGlyph.card ||
    OnboardingGlyph.bars ||
    OnboardingGlyph.shield => c.borderStrong,
    OnboardingGlyph.coin ||
    OnboardingGlyph.ring ||
    OnboardingGlyph.lock => c.accentDeep,
    OnboardingGlyph.arrow ||
    OnboardingGlyph.spark ||
    OnboardingGlyph.key => c.successDeep,
  };
}

/// Paints one NeoPOP glyph: a flat face with a solid bottom/right edge.
/// Everything is drawn from primitives; no assets.
class OnboardingGlyphPainter extends CustomPainter {
  const OnboardingGlyphPainter({
    required this.glyph,
    required this.face,
    required this.edge,
    required this.outline,
    required this.ink,
  });

  final OnboardingGlyph glyph;
  final Color face;
  final Color edge;
  final Color outline;
  final Color ink;

  static const double _depth = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    switch (glyph) {
      case OnboardingGlyph.card:
        _card(canvas, s);
      case OnboardingGlyph.coin:
        _coin(canvas, s);
      case OnboardingGlyph.arrow:
        _arrow(canvas, s);
      case OnboardingGlyph.bars:
        _bars(canvas, s);
      case OnboardingGlyph.ring:
        _ring(canvas, s);
      case OnboardingGlyph.spark:
        _spark(canvas, s);
      case OnboardingGlyph.shield:
        _shield(canvas, s);
      case OnboardingGlyph.lock:
        _lock(canvas, s);
      case OnboardingGlyph.key:
        _key(canvas, s);
    }
  }

  Paint _fill(Color color) => Paint()..color = color;

  /// A rectangle with its edge faces, like `FpSurface`.
  void _plunkRect(Canvas canvas, Rect r, {Color? faceColor}) {
    canvas
      ..drawRect(r.shift(const Offset(_depth, _depth)), _fill(edge))
      ..drawRect(r, _fill(faceColor ?? face))
      ..drawRect(
        r,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke,
      );
  }

  void _plunkCircle(Canvas canvas, Offset center, double radius) {
    canvas
      ..drawCircle(center + const Offset(_depth, _depth), radius, _fill(edge))
      ..drawCircle(center, radius, _fill(face));
  }

  void _card(Canvas canvas, double s) {
    final r = Rect.fromLTWH(s * 0.12, s * 0.22, s * 0.62, s * 0.4);
    _plunkRect(canvas, r);
    // Chip and a number band.
    canvas
      ..drawRect(
        Rect.fromLTWH(r.left + s * 0.06, r.top + s * 0.08, s * 0.1, s * 0.08),
        _fill(edge),
      )
      ..drawRect(
        Rect.fromLTWH(r.left + s * 0.06, r.bottom - s * 0.1, s * 0.3, s * 0.03),
        _fill(outline),
      );
  }

  void _coin(Canvas canvas, double s) {
    final center = Offset(s * 0.68, s * 0.6);
    _plunkCircle(canvas, center, s * 0.16);
    final tp = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          color: ink,
          fontSize: s * 0.16,
          fontWeight: FontWeight.w800,
          fontFamily: FpTypography.uiFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _arrow(Canvas canvas, double s) {
    final path = Path()
      ..moveTo(s * 0.3, s * 0.78)
      ..lineTo(s * 0.52, s * 0.78)
      ..lineTo(s * 0.52, s * 0.72)
      ..lineTo(s * 0.62, s * 0.82)
      ..lineTo(s * 0.52, s * 0.92)
      ..lineTo(s * 0.52, s * 0.86)
      ..lineTo(s * 0.3, s * 0.86)
      ..close();
    canvas
      ..drawPath(path.shift(const Offset(_depth, _depth)), _fill(edge))
      ..drawPath(path, _fill(face));
  }

  void _bars(Canvas canvas, double s) {
    final heights = [0.28, 0.44, 0.36, 0.58];
    for (var i = 0; i < heights.length; i++) {
      final h = s * heights[i];
      final r = Rect.fromLTWH(s * (0.12 + i * 0.17), s * 0.78 - h, s * 0.11, h);
      _plunkRect(canvas, r);
    }
  }

  void _ring(Canvas canvas, double s) {
    final center = Offset(s * 0.7, s * 0.3);
    final rect = Rect.fromCircle(center: center, radius: s * 0.14);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.butt;
    canvas
      ..drawArc(
        rect.shift(const Offset(_depth, _depth)),
        -math.pi / 2,
        math.pi * 1.5,
        false,
        stroke..color = edge,
      )
      ..drawArc(rect, -math.pi / 2, math.pi * 1.5, false, stroke..color = face);
  }

  void _spark(Canvas canvas, double s) {
    final c = Offset(s * 0.36, s * 0.26);
    final r = s * 0.09;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.3, c.dy - r * 0.3)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r * 0.3, c.dy + r * 0.3)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.3, c.dy + r * 0.3)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r * 0.3, c.dy - r * 0.3)
      ..close();
    canvas
      ..drawPath(path.shift(const Offset(_depth / 2, _depth / 2)), _fill(edge))
      ..drawPath(path, _fill(face));
  }

  void _shield(Canvas canvas, double s) {
    final path = Path()
      ..moveTo(s * 0.5, s * 0.12)
      ..lineTo(s * 0.8, s * 0.24)
      ..lineTo(s * 0.8, s * 0.5)
      ..quadraticBezierTo(s * 0.8, s * 0.74, s * 0.5, s * 0.86)
      ..quadraticBezierTo(s * 0.2, s * 0.74, s * 0.2, s * 0.5)
      ..lineTo(s * 0.2, s * 0.24)
      ..close();
    canvas
      ..drawPath(path.shift(const Offset(_depth, _depth)), _fill(edge))
      ..drawPath(path, _fill(face))
      ..drawPath(
        path,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke,
      );
  }

  void _lock(Canvas canvas, double s) {
    final body = Rect.fromLTWH(s * 0.36, s * 0.46, s * 0.28, s * 0.22);
    final shackle = Rect.fromLTWH(s * 0.41, s * 0.32, s * 0.18, s * 0.2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..color = edge;
    canvas.drawArc(shackle, math.pi, math.pi, false, stroke);
    _plunkRect(canvas, body);
    canvas.drawCircle(body.center, s * 0.03, _fill(ink));
  }

  void _key(Canvas canvas, double s) {
    final head = Offset(s * 0.24, s * 0.72);
    final shaft = Rect.fromLTWH(s * 0.3, s * 0.7, s * 0.26, s * 0.04);
    canvas
      ..drawCircle(
        head + const Offset(_depth / 2, _depth / 2),
        s * 0.07,
        _fill(edge),
      )
      ..drawCircle(head, s * 0.07, _fill(face))
      ..drawCircle(head, s * 0.025, _fill(ink))
      ..drawRect(shaft.shift(const Offset(_depth / 2, _depth / 2)), _fill(edge))
      ..drawRect(shaft, _fill(face))
      ..drawRect(
        Rect.fromLTWH(s * 0.5, s * 0.74, s * 0.03, s * 0.04),
        _fill(face),
      )
      ..drawRect(
        Rect.fromLTWH(s * 0.44, s * 0.74, s * 0.03, s * 0.03),
        _fill(face),
      );
  }

  @override
  bool shouldRepaint(OnboardingGlyphPainter old) =>
      old.glyph != glyph ||
      old.face != face ||
      old.edge != edge ||
      old.outline != outline ||
      old.ink != ink;
}
