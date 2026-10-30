import 'dart:math' as math;

import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/screens/home/home_header_math.dart';
import 'package:flutter/material.dart';

/// Which code-drawn badge an offer shows.
enum OfferBadge { percent, bolt, ring }

/// A demo offer (original copy; nothing real is redeemed).
@immutable
class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final String id;
  final String title;
  final String subtitle;
  final OfferBadge badge;

  /// The demo offers shown on home.
  static const List<Offer> demo = [
    Offer(
      id: 'cashback',
      title: '5% back on groceries',
      subtitle: 'Pay with any saved card until Sunday.',
      badge: OfferBadge.percent,
    ),
    Offer(
      id: 'transfers',
      title: 'Zero-fee transfers',
      subtitle: 'Send up to ₹25,000 this week, no charges.',
      badge: OfferBadge.bolt,
    ),
    Offer(
      id: 'invite',
      title: 'Invite a friend',
      subtitle: 'You both get ₹100 when they pay once.',
      badge: OfferBadge.ring,
    ),
  ];
}

/// Horizontal carousel of offers whose cards turn in 3D as they scroll
/// (flat under reduce motion).
class OffersCarousel extends StatefulWidget {
  const OffersCarousel({super.key, this.offers = Offer.demo, this.onOffer});

  final List<Offer> offers;
  final ValueChanged<Offer>? onOffer;

  /// Height of the carousel.
  static const double height = 132;

  @override
  State<OffersCarousel> createState() => _OffersCarouselState();
}

class _OffersCarouselState extends State<OffersCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.8);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = FpMotion.of(context).reduce;
    return SizedBox(
      height: OffersCarousel.height,
      child: PageView.builder(
        key: const ValueKey('home-offers'),
        controller: _controller,
        padEnds: false,
        itemCount: widget.offers.length,
        itemBuilder: (context, i) {
          final offer = widget.offers[i];
          final card = Padding(
            padding: const EdgeInsets.only(
              left: FpSpacing.lg,
              right: FpSpacing.xs,
            ),
            child: _OfferCard(offer: offer, onTap: widget.onOffer),
          );
          if (reduce) return card;
          return AnimatedBuilder(
            animation: _controller,
            child: card,
            builder: (context, child) {
              final page = _controller.hasClients && _controller.page != null
                  ? _controller.page!
                  : 0.0;
              return Transform(
                key: ValueKey('offer-tilt-$i'),
                transform: OfferTilt.transform(i - page),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, this.onTap});

  final Offer offer;
  final ValueChanged<Offer>? onTap;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return RepaintBoundary(
      child: FpSurface(
        key: ValueKey('offer-${offer.id}'),
        semanticLabel: '${offer.title}. ${offer.subtitle}',
        onTap: onTap == null ? null : () => onTap!(offer),
        padding: const EdgeInsets.all(FpSpacing.md),
        child: ExcludeSemantics(
          child: Row(
            children: [
              CustomPaint(
                size: const Size.square(56),
                painter: OfferBadgePainter(
                  badge: offer.badge,
                  face: c.accent,
                  ink: c.onPop,
                  edge: FpEdge.accent,
                ),
              ),
              const SizedBox(width: FpSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      style: fp.text.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: FpSpacing.xs),
                    Text(
                      offer.subtitle,
                      style: fp.text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a NeoPOP badge tile with a simple glyph: a percent sign, a bolt
/// or a ring. Pure geometry, no assets.
class OfferBadgePainter extends CustomPainter {
  const OfferBadgePainter({
    required this.badge,
    required this.face,
    required this.ink,
    required this.edge,
  });

  final OfferBadge badge;
  final Color face;
  final Color ink;
  final FpEdge edge;

  @override
  void paint(Canvas canvas, Size size) {
    const depth = FpDepth.button;
    final body = Rect.fromLTWH(0, 0, size.width - depth, size.height - depth);
    canvas
      ..drawRect(
        Rect.fromLTWH(body.right, depth, depth, body.height),
        Paint()..color = edge.right,
      )
      ..drawRect(
        Rect.fromLTWH(depth, body.bottom, body.width, depth),
        Paint()..color = edge.bottom,
      )
      ..drawRect(body, Paint()..color = face);
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = body.width * 0.07
      ..strokeCap = StrokeCap.square;
    final fill = Paint()..color = ink;
    final c = body.center;
    final r = body.width * 0.3;
    switch (badge) {
      case OfferBadge.percent:
        canvas
          ..drawLine(
            Offset(c.dx - r, c.dy + r),
            Offset(c.dx + r, c.dy - r),
            stroke,
          )
          ..drawCircle(Offset(c.dx - r * 0.55, c.dy - r * 0.55), r * 0.3, fill)
          ..drawCircle(Offset(c.dx + r * 0.55, c.dy + r * 0.55), r * 0.3, fill);
      case OfferBadge.bolt:
        final path = Path()
          ..moveTo(c.dx + r * 0.3, c.dy - r)
          ..lineTo(c.dx - r * 0.6, c.dy + r * 0.15)
          ..lineTo(c.dx - r * 0.05, c.dy + r * 0.15)
          ..lineTo(c.dx - r * 0.3, c.dy + r)
          ..lineTo(c.dx + r * 0.6, c.dy - r * 0.15)
          ..lineTo(c.dx + r * 0.05, c.dy - r * 0.15)
          ..close();
        canvas.drawPath(path, fill);
      case OfferBadge.ring:
        canvas
          ..drawCircle(c, r, stroke)
          ..drawArc(
            Rect.fromCircle(center: c, radius: r * 0.55),
            -math.pi / 2,
            math.pi * 1.5,
            false,
            stroke,
          );
    }
  }

  @override
  bool shouldRepaint(OfferBadgePainter old) =>
      old.badge != badge || old.face != face || old.ink != ink;
}
