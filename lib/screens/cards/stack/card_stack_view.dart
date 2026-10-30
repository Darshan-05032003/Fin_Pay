import 'dart:math' as math;

import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_cubit.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_math.dart';
import 'package:fin_pay/screens/cards/stack/cvv_reveal_cubit.dart';
import 'package:fin_pay/screens/cards/widgets/payment_card_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Hero tag shared by the home preview, the stack and the details screen.
String cardHeroTag(String cardId) => 'card-$cardId';

/// The CRED-style card stack.
///
/// Collapsed: a pile (focused card on top, the rest peeking out below).
/// Tap → the pile fans out on a spring into a horizontal carousel with
/// perspective; swipe between cards; tap the front card to flip it; the
/// back shows the masked CVV with a timed reveal. The front card tilts with
/// the motion sensor (through [tilt]) or under the finger.
class CardStackView extends StatefulWidget {
  const CardStackView({
    required this.cards,
    required this.tilt,
    required this.sensorAvailable,
    super.key,
    this.onOpenDetails,
  });

  final List<PaymentCard> cards;
  final FpTiltController tilt;

  /// When false the tilt follows the finger instead of the sensor.
  final bool sensorAvailable;
  final ValueChanged<PaymentCard>? onOpenDetails;

  @override
  State<CardStackView> createState() => _CardStackViewState();
}

class _CardStackViewState extends State<CardStackView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fan = AnimationController(
    vsync: this,
    value: context.read<CardStackCubit>().state.fanned ? 1 : 0,
  );
  PageController? _page;
  double _fanTarget = 0;

  /// Fan-out progress (tests).
  double get fanProgress => _fan.value;

  @override
  void initState() {
    super.initState();
    _fanTarget = _fan.value;
    // A spring settles a hair short of its target; snap so the carousel
    // swaps in exactly at 1 and the pile exactly at 0.
    _fan.addStatusListener((status) {
      if (!status.isAnimating) _fan.value = _fanTarget;
    });
  }

  @override
  void dispose() {
    _fan.dispose();
    _page?.dispose();
    super.dispose();
  }

  void _onStateChanged(CardStackState state) {
    final target = state.fanned ? 1.0 : 0.0;
    _fanTarget = target;
    if (_fan.value == target) return;
    if (FpMotion.of(context).reduce) {
      _fan.value = target;
      return;
    }
    _fan.animateWith(
      FpSprings.simulation(FpSprings.sheet, start: _fan.value, end: target),
    );
  }

  PageController _controllerFor(int focused) {
    final existing = _page;
    if (existing != null) return existing;
    return _page = PageController(
      initialPage: focused,
      viewportFraction: CardStackMath.viewportFraction,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CardStackCubit, CardStackState>(
      listener: (context, state) => _onStateChanged(state),
      builder: (context, state) {
        final cards = widget.cards;
        if (cards.isEmpty) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cardWidth =
                width * CardStackMath.viewportFraction - FpSpacing.lg;
            final cardHeight = CardStackMath.cardHeight(cardWidth);
            final height = CardStackMath.pileHeight(cards.length, cardHeight);
            return SizedBox(
              height: height,
              child: AnimatedBuilder(
                animation: _fan,
                builder: (context, _) {
                  final t = _fan.value.clamp(0.0, 1.0);
                  if (state.fanned && t >= 1) {
                    return _Carousel(
                      cards: cards,
                      state: state,
                      controller: _controllerFor(state.focused),
                      cardWidth: cardWidth,
                      width: width,
                      tilt: widget.tilt,
                      sensorAvailable: widget.sensorAvailable,
                      onOpenDetails: widget.onOpenDetails,
                    );
                  }
                  return _Pile(
                    cards: cards,
                    state: state,
                    t: t,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    width: width,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// The collapsed pile, and the in-between frames of the fan-out spring.
class _Pile extends StatelessWidget {
  const _Pile({
    required this.cards,
    required this.state,
    required this.t,
    required this.cardWidth,
    required this.cardHeight,
    required this.width,
  });

  final List<PaymentCard> cards;
  final CardStackState state;
  final double t;
  final double cardWidth;
  final double cardHeight;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CardStackCubit>();
    final focused = state.focused;
    final count = cards.length;
    // Paint deepest first so the focused card ends up on top.
    final order = List<int>.generate(count, (i) => i)
      ..sort(
        (a, b) => CardStackMath.depth(
          b,
          focused,
          count,
        ).compareTo(CardStackMath.depth(a, focused, count)),
      );
    final left = (width - cardWidth) / 2;
    return FpPressable(
      semanticLabel: count == 1
          ? 'Your card, tap to open'
          : 'Your $count cards, tap to fan out',
      onPressed: cubit.fanOut,
      scale: 0.98,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final i in order)
            if (_slot(i).visible)
              Positioned(
                left: left,
                top: 0,
                width: cardWidth,
                height: cardHeight,
                child: Transform(
                  transform: _matrix(_slot(i), cardWidth, cardHeight),
                  child: ExcludeSemantics(
                    child: i == focused
                        ? FpHero(
                            tag: cardHeroTag(cards[i].id),
                            child: PaymentCardArt.of(cards[i]),
                          )
                        : PaymentCardArt.of(cards[i]),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  CardSlot _slot(int i) {
    final stacked = CardStackMath.stacked(i, state.focused, cards.length);
    if (t <= 0) return stacked;
    final fanned = CardStackMath.fanned(i, state.focused.toDouble(), width);
    return stacked.lerp(fanned, t);
  }

  static Matrix4 _matrix(CardSlot slot, double w, double h) =>
      Matrix4.identity()
        ..setEntry(3, 2, FpTiltMath.perspective)
        ..translateByDouble(slot.dx, slot.dy, 0, 1)
        ..translateByDouble(w / 2, 0, 0, 1)
        ..rotateY(slot.rotationY)
        ..scaleByDouble(slot.scale, slot.scale, 1, 1)
        ..translateByDouble(-w / 2, 0, 0, 1);
}

/// The fanned carousel: a real `PageView` for physics, each page turned
/// towards the viewer by its distance from the centre.
class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.cards,
    required this.state,
    required this.controller,
    required this.cardWidth,
    required this.width,
    required this.tilt,
    required this.sensorAvailable,
    this.onOpenDetails,
  });

  final List<PaymentCard> cards;
  final CardStackState state;
  final PageController controller;
  final double cardWidth;
  final double width;
  final FpTiltController tilt;
  final bool sensorAvailable;
  final ValueChanged<PaymentCard>? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CardStackCubit>();
    return PageView.builder(
      key: const ValueKey('card-carousel'),
      controller: controller,
      itemCount: cards.length,
      onPageChanged: cubit.focus,
      itemBuilder: (context, i) {
        final card = cards[i];
        final focused = i == state.focused;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final page = controller.hasClients && controller.page != null
                ? controller.page!
                : state.focused.toDouble();
            final slot = CardStackMath.fanned(i, page, width);
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, FpTiltMath.perspective)
                ..rotateY(slot.rotationY)
                ..scaleByDouble(slot.scale, slot.scale, 1, 1),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: cardWidth,
              child: focused
                  ? _FocusedCard(
                      card: card,
                      flipped: state.isFlipped(card.id),
                      tilt: tilt,
                      sensorAvailable: sensorAvailable,
                      onFlip: () => cubit.flip(card.id),
                      onOpenDetails: onOpenDetails,
                    )
                  // Neighbours are mostly off-screen, so they are described
                  // but not exposed as tap targets; swiping focuses them.
                  : Semantics(
                      label: '${PaymentCardArt.describe(card)}, swipe to focus',
                      child: ExcludeSemantics(
                        child: FpPressable(
                          onPressed: () => controller.animateToPage(
                            i,
                            duration: FpMotion.emphasized,
                            curve: FpMotion.standardCurve,
                          ),
                          child: PaymentCardArt.of(card),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// The front card: tilt + flip + CVV reveal on the back.
class _FocusedCard extends StatelessWidget {
  const _FocusedCard({
    required this.card,
    required this.flipped,
    required this.tilt,
    required this.sensorAvailable,
    required this.onFlip,
    this.onOpenDetails,
  });

  final PaymentCard card;
  final bool flipped;
  final FpTiltController tilt;
  final bool sensorAvailable;
  final VoidCallback onFlip;
  final ValueChanged<PaymentCard>? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final label = PaymentCardArt.describe(card);
    return FpTiltCard(
      controller: tilt,
      dragFallback: !sensorAvailable,
      child: FpFlipCard(
        key: ValueKey('focused-card-${card.id}'),
        flipped: flipped,
        onTap: onFlip,
        semanticLabel: flipped
            ? '$label, back. Tap to turn over'
            : '$label. Tap to see the back',
        front: FpHero(
          tag: cardHeroTag(card.id),
          child: PaymentCardArt.of(card),
        ),
        back: CardBackWithCvv(card: card),
      ),
    );
  }
}

/// The back of a card with the masked CVV, a reveal button and the
/// countdown while it is shown.
class CardBackWithCvv extends StatelessWidget {
  const CardBackWithCvv({required this.card, super.key, this.compact = false});

  final PaymentCard card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    return BlocBuilder<CvvRevealCubit, CvvRevealState>(
      builder: (context, state) {
        final cubit = context.read<CvvRevealCubit>();
        final revealed = state.isRevealed(card.id);
        final loading = state.isLoading(card.id);
        final cvv = revealed ? cubit.cvv ?? PaymentCardArt.maskedCvv : null;
        final seconds = math.max(0, state.remaining.inSeconds);
        return PaymentCardArt.of(
          card,
          side: CardSide.back,
          compact: compact,
          cvvText: cvv ?? PaymentCardArt.maskedCvv,
          cvvTrailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FpPressable(
                key: ValueKey('reveal-cvv-${card.id}'),
                semanticLabel: revealed
                    ? 'Hide CVV, hides itself in $seconds seconds'
                    : 'Reveal CVV for 5 seconds',
                onPressed: revealed ? cubit.hide : () => cubit.reveal(card.id),
                onLongPress: revealed ? null : () => cubit.reveal(card.id),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fp.colors.surfaceHigh,
                    border: Border.all(color: fp.colors.borderStrong),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FpSpacing.md,
                      vertical: FpSpacing.sm,
                    ),
                    child: Text(
                      loading
                          ? 'READING…'
                          : revealed
                          ? 'HIDE CVV'
                          : 'REVEAL CVV',
                      style: fp.text.overline.copyWith(
                        color: fp.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              if (revealed) ...[
                const SizedBox(width: FpSpacing.sm),
                FpCountdownRing(
                  progress: cubit.ttl.inMilliseconds == 0
                      ? 0
                      : state.remaining.inMilliseconds /
                            cubit.ttl.inMilliseconds,
                  label: '$seconds',
                  size: 28,
                  semanticLabel: 'CVV hides in $seconds seconds',
                ),
              ],
              if (state.status == CvvRevealStatus.failed &&
                  state.cardId == card.id) ...[
                const SizedBox(width: FpSpacing.sm),
                Text(
                  'Unavailable',
                  style: fp.text.caption.copyWith(color: fp.colors.alert),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
