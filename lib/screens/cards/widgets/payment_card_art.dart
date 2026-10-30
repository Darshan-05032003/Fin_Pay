import 'dart:math' as math;

import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/screens/cards/add_card/card_validators.dart';
import 'package:flutter/material.dart';

/// Which side of a card is drawn.
enum CardSide { front, back }

/// Original, code-drawn card art: a NeoPOP face (solid colour, flat
/// pattern, bottom/right edge) per network, with neutral text labels
/// instead of network logos. Front shows the number, holder and expiry;
/// back shows the magnetic stripe and the signature strip with the CVV
/// slot.
class PaymentCardArt extends StatelessWidget {
  const PaymentCardArt({
    required this.network,
    required this.number,
    required this.holder,
    required this.expiry,
    super.key,
    this.side = CardSide.front,
    this.cvvText = maskedCvv,
    this.cvvTrailing,
    this.compact = false,
    this.frozen = false,
    this.semanticLabel,
  });

  /// Art for a stored card (always masked: `•••• •••• •••• 1234`).
  PaymentCardArt.of(
    PaymentCard card, {
    super.key,
    this.side = CardSide.front,
    this.cvvText = maskedCvv,
    this.cvvTrailing,
    this.compact = false,
    this.frozen = false,
  }) : network = CardNetwork.forType(card.cardType),
       number = maskedNumber(card.last4),
       holder = card.cardHolderName,
       expiry = card.expireDate,
       semanticLabel = describe(card);

  final CardNetwork network;

  /// The number as displayed (grouped, masked or bulleted).
  final String number;
  final String holder;
  final String expiry;
  final CardSide side;

  /// Text in the CVV slot on the back.
  final String cvvText;

  /// Control under the CVV slot (reveal button, countdown).
  final Widget? cvvTrailing;

  /// Smaller type for the home preview.
  final bool compact;

  /// Draws the "frozen" overlay.
  final bool frozen;
  final String? semanticLabel;

  /// The masked CVV slot text.
  static const String maskedCvv = '•••';

  /// Card aspect ratio (ISO/IEC 7810 ID-1).
  static const double aspectRatio = 85.6 / 53.98;

  /// `•••• •••• •••• 1234`.
  static String maskedNumber(String last4) =>
      '•••• •••• •••• ${last4.isEmpty ? '••••' : last4}';

  /// Accessibility summary of a stored card.
  static String describe(PaymentCard card) {
    final network = CardNetwork.forType(card.cardType).label;
    return '$network card ending ${card.last4}, expires ${card.expireDate}, '
        '${card.cardHolderName}';
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final palette = _CardPalette.forNetwork(network, c);
    final body = AspectRatio(
      aspectRatio: aspectRatio,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CardFacePainter(
            network: network,
            palette: palette,
            back: side == CardSide.back,
            depth: fp.metrics.depthSurface,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (side == CardSide.front)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? FpSpacing.md : FpSpacing.lg,
                    compact ? FpSpacing.md : FpSpacing.lg,
                    (compact ? FpSpacing.md : FpSpacing.lg) +
                        fp.metrics.depthSurface,
                    (compact ? FpSpacing.md : FpSpacing.lg) +
                        fp.metrics.depthSurface,
                  ),
                  child: _Front(
                    network: network,
                    number: number,
                    holder: holder,
                    expiry: expiry,
                    palette: palette,
                    compact: compact,
                  ),
                )
              else
                _Back(
                  network: network,
                  cvvText: cvvText,
                  trailing: cvvTrailing,
                  palette: palette,
                  compact: compact,
                  depth: fp.metrics.depthSurface,
                  stripe: c.background,
                ),
              if (frozen)
                Positioned.fill(
                  child: ColoredBox(
                    color: c.background.withValues(alpha: 0.6),
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.surfaceHigh,
                          border: Border.all(color: c.borderStrong),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FpSpacing.md,
                            vertical: FpSpacing.sm,
                          ),
                          child: Text(
                            'FROZEN',
                            style: fp.text.label.copyWith(color: c.info),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final label = semanticLabel;
    if (label == null) return body;
    return Semantics(
      container: true,
      label: frozen ? '$label, frozen' : label,
      child: ExcludeSemantics(child: body),
    );
  }
}

class _Front extends StatelessWidget {
  const _Front({
    required this.network,
    required this.number,
    required this.holder,
    required this.expiry,
    required this.palette,
    required this.compact,
  });

  final CardNetwork network;
  final String number;
  final String holder;
  final String expiry;
  final _CardPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final numberStyle = (compact ? fp.text.body : fp.text.title).copyWith(
      color: palette.text,
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: compact ? 1.5 : 2.5,
      fontWeight: FontWeight.w700,
    );
    final overline = fp.text.overline.copyWith(color: palette.textMuted);
    final value = (compact ? fp.text.caption : fp.text.bodySmall).copyWith(
      color: palette.text,
      fontWeight: FontWeight.w700,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              network.label.toUpperCase(),
              style: fp.text.label.copyWith(
                color: palette.text,
                fontSize: compact ? 11 : 14,
              ),
            ),
            const Spacer(),
            CustomPaint(
              size: Size(compact ? 24 : 34, compact ? 18 : 26),
              painter: _ChipPainter(face: palette.chip, line: palette.chipLine),
            ),
          ],
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(number, style: numberStyle, maxLines: 1),
        ),
        SizedBox(height: compact ? FpSpacing.sm : FpSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CARD HOLDER', style: overline, maxLines: 1),
                  Text(
                    holder.isEmpty ? 'YOUR NAME' : holder.toUpperCase(),
                    style: value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: FpSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('VALID THRU', style: overline, maxLines: 1),
                Text(expiry.isEmpty ? 'MM/YY' : expiry, style: value),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({
    required this.network,
    required this.cvvText,
    required this.palette,
    required this.compact,
    required this.depth,
    required this.stripe,
    this.trailing,
  });

  final CardNetwork network;
  final String cvvText;
  final Widget? trailing;
  final _CardPalette palette;
  final bool compact;
  final double depth;
  final Color stripe;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final pad = compact ? FpSpacing.md : FpSpacing.lg;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight - depth;
        return Padding(
          padding: EdgeInsets.only(right: depth, bottom: depth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: h * 0.1),
              // Magnetic stripe, full bleed.
              ColoredBox(
                color: stripe,
                child: SizedBox(height: h * 0.18, width: double.infinity),
              ),
              SizedBox(height: h * 0.08),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: _signature(fp, c),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (trailing != null)
                      trailing!
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    Text(
                      network.label.toUpperCase(),
                      style: fp.text.label.copyWith(
                        color: palette.text,
                        fontSize: compact ? 11 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _signature(FpTokens fp, FpColorScheme c) {
    return Row(
      children: [
        // Intrinsic width (not Expanded): the label's bounds are the glyphs
        // themselves, which keeps contrast measurement honest over the
        // patterned face.
        Flexible(
          child: Text(
            'AUTHORISED SIGNATURE',
            style: fp.text.overline.copyWith(color: palette.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        // The CVV sits in its own white box, as on a real card.
        Container(
          height: compact ? 22 : 30,
          padding: const EdgeInsets.symmetric(horizontal: FpSpacing.sm),
          alignment: Alignment.center,
          color: c.popWhite,
          child: Text(
            cvvText,
            key: const ValueKey('card-cvv-text'),
            style: fp.text.numeric.copyWith(
              color: c.onPop,
              letterSpacing: 3,
              fontSize: compact ? 13 : 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Colours of one network's face, all from the tokens.
class _CardPalette {
  const _CardPalette({
    required this.face,
    required this.edge,
    required this.pattern,
    required this.text,
    required this.textMuted,
    required this.chip,
    required this.chipLine,
  });

  factory _CardPalette.forNetwork(CardNetwork network, FpColorScheme c) =>
      switch (network) {
        CardNetwork.visa => _CardPalette(
          face: c.surfaceHigh,
          edge: FpEdge.surfaceRaised,
          pattern: c.info.withValues(alpha: 0.16),
          text: c.textPrimary,
          textMuted: c.textSecondary,
          chip: c.popWhite,
          chipLine: c.surfaceHigh,
        ),
        CardNetwork.mastercard => _CardPalette(
          face: c.accent,
          edge: FpEdge.accent,
          pattern: c.accentDeep.withValues(alpha: 0.5),
          text: c.onPop,
          textMuted: c.onPop,
          chip: c.onPop,
          chipLine: c.accent,
        ),
        CardNetwork.rupay => _CardPalette(
          face: c.success,
          edge: FpEdge.success,
          pattern: c.successDeep.withValues(alpha: 0.45),
          text: c.onPop,
          textMuted: c.onPop,
          chip: c.onPop,
          chipLine: c.success,
        ),
        CardNetwork.unknown => _CardPalette(
          face: c.surfaceRaised,
          edge: FpEdge.surfaceRaised,
          pattern: c.border,
          text: c.textPrimary,
          textMuted: c.textSecondary,
          chip: c.popWhite,
          chipLine: c.surfaceRaised,
        ),
      };

  final Color face;
  final FpEdge edge;
  final Color pattern;
  final Color text;
  final Color textMuted;
  final Color chip;
  final Color chipLine;
}

class _CardFacePainter extends CustomPainter {
  const _CardFacePainter({
    required this.network,
    required this.palette,
    required this.back,
    required this.depth,
  });

  final CardNetwork network;
  final _CardPalette palette;
  final bool back;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width - depth, size.height - depth);
    canvas
      ..drawRect(
        Rect.fromLTWH(body.right, depth, depth, body.height),
        Paint()..color = palette.edge.right,
      )
      ..drawRect(
        Rect.fromLTWH(depth, body.bottom, body.width, depth),
        Paint()..color = palette.edge.bottom,
      )
      ..drawRect(body, Paint()..color = palette.face)
      ..save()
      ..clipRect(body);
    _pattern(canvas, body);
    canvas.restore();
  }

  void _pattern(Canvas canvas, Rect body) {
    final paint = Paint()..color = palette.pattern;
    switch (network) {
      case CardNetwork.visa:
        // Three diagonal bands across the right half.
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = body.width * 0.07;
        for (var i = 0; i < 3; i++) {
          final x = body.width * (0.55 + i * 0.16);
          canvas.drawLine(
            Offset(x, body.bottom + 10),
            Offset(x + body.height * 0.6, body.top - 10),
            paint,
          );
        }
      case CardNetwork.mastercard:
        // Concentric arcs in the bottom-right corner.
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = body.width * 0.03;
        final centre = Offset(body.right - body.width * 0.1, body.bottom);
        for (var r = 1; r <= 4; r++) {
          canvas.drawCircle(centre, body.height * 0.18 * r, paint);
        }
      case CardNetwork.rupay:
        // Chevrons marching up the left side.
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = body.width * 0.025
          ..strokeJoin = StrokeJoin.miter;
        final w = body.width * 0.16;
        for (var i = 0; i < 5; i++) {
          final y = body.top + body.height * (0.15 + i * 0.2);
          final path = Path()
            ..moveTo(body.left - 4, y + w * 0.5)
            ..lineTo(body.left + w * 0.5, y)
            ..lineTo(body.left + w + 4, y + w * 0.5);
          canvas.drawPath(path, paint);
        }
      case CardNetwork.unknown:
        // A quiet dot grid.
        paint.style = PaintingStyle.fill;
        const step = 14.0;
        for (var x = body.left + step; x < body.right; x += step) {
          for (var y = body.top + step; y < body.bottom; y += step) {
            canvas.drawCircle(Offset(x, y), 1, paint);
          }
        }
    }
  }

  @override
  bool shouldRepaint(_CardFacePainter old) =>
      old.network != network ||
      old.back != back ||
      old.palette.face != palette.face ||
      old.depth != depth;
}

/// A generic EMV-style chip: a rounded rectangle with contact lines.
class _ChipPainter extends CustomPainter {
  const _ChipPainter({required this.face, required this.line});

  final Color face;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = face,
    );
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas
      ..drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint,
      )
      ..drawRect(
        Rect.fromCenter(
          center: rect.center,
          width: size.width * 0.4,
          height: size.height * 0.4,
        ),
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_ChipPainter old) => old.face != face || old.line != line;
}

/// The preview of a card being typed: live number grouping, holder and
/// expiry, flipping to the back while the CVV is edited.
class LiveCardPreview extends StatelessWidget {
  const LiveCardPreview({
    required this.network,
    required this.number,
    required this.holder,
    required this.expiry,
    required this.cvvLength,
    required this.showBack,
    super.key,
  });

  final CardNetwork network;
  final String number;
  final String holder;
  final String expiry;
  final int cvvLength;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final reduce = FpMotion.of(context).reduce;
    // The network mark cross-fades when the BIN changes.
    Widget face(CardSide side) => AnimatedSwitcher(
      duration: reduce ? Duration.zero : FpMotion.standard,
      switchInCurve: FpMotion.standardDecelerate,
      switchOutCurve: FpMotion.emphasizedAccelerate,
      child: PaymentCardArt(
        key: ValueKey('${network.name}-${side.name}'),
        network: network,
        number: number,
        holder: holder,
        expiry: expiry,
        side: side,
        cvvText: '•' * math.min(cvvLength, CardValidators.cvvLength + 1),
      ),
    );
    return FpFlipCard(
      flipped: showBack,
      semanticLabel: showBack
          ? 'Card preview, back'
          : 'Card preview, ${network.label} $number',
      front: face(CardSide.front),
      back: face(CardSide.back),
    );
  }
}
