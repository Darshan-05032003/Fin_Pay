import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_cubit.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CardStackMath', () {
    test('depth wraps so the focused card is on top', () {
      expect(CardStackMath.depth(0, 0, 3), 0);
      expect(CardStackMath.depth(1, 0, 3), 1);
      expect(CardStackMath.depth(2, 0, 3), 2);
      expect(CardStackMath.depth(0, 2, 3), 1);
      expect(CardStackMath.depth(1, 2, 3), 2);
      expect(CardStackMath.depth(5, 1, 0), 0);
    });

    test('stacked: peeks and shrinks with depth, hides the deep ones', () {
      final top = CardStackMath.stacked(0, 0, 10);
      expect(top.dy, 0);
      expect(top.scale, 1);
      expect(top.visible, isTrue);
      final second = CardStackMath.stacked(1, 0, 10);
      expect(second.dy, CardStackMath.peek);
      expect(second.scale, closeTo(1 - CardStackMath.pileScaleStep, 1e-9));
      final deep = CardStackMath.stacked(7, 0, 10);
      expect(deep.visible, isFalse);
      expect(deep.dy, (CardStackMath.maxPileDepth - 1) * CardStackMath.peek);
    });

    test('fanned: neighbours sit a page away, turned and smaller', () {
      final centre = CardStackMath.fanned(1, 1, 400);
      expect(centre.dx, 0);
      expect(centre.scale, 1);
      expect(centre.rotationY, 0);
      final right = CardStackMath.fanned(2, 1, 400);
      expect(right.dx, closeTo(400 * CardStackMath.viewportFraction, 1e-9));
      expect(right.rotationY, closeTo(-CardStackMath.fanAngle, 1e-9));
      expect(right.scale, closeTo(1 - CardStackMath.fanScaleStep, 1e-9));
      final left = CardStackMath.fanned(0, 1, 400);
      expect(left.dx, lessThan(0));
      expect(left.rotationY, closeTo(CardStackMath.fanAngle, 1e-9));
      // Half-way through a swipe the rotation is half.
      expect(
        CardStackMath.fanned(1, 1.5, 400).rotationY,
        closeTo(CardStackMath.fanAngle / 2, 1e-9),
      );
      // Far pages are clamped in rotation, floored in scale, hidden.
      final far = CardStackMath.fanned(9, 1, 400);
      expect(far.rotationY, closeTo(-CardStackMath.fanAngle, 1e-9));
      expect(far.scale, 0.6);
      expect(far.visible, isFalse);
    });

    test('lerp between slots', () {
      final a = CardStackMath.stacked(1, 0, 3);
      final b = CardStackMath.fanned(1, 0, 400);
      final mid = a.lerp(b, 0.5);
      expect(mid.dx, closeTo(b.dx / 2, 1e-9));
      expect(mid.dy, closeTo(a.dy / 2, 1e-9));
      expect(mid.visible, isTrue);
      expect(a.lerp(b, 0).dx, 0);
      expect(a.lerp(b, 2).dx, b.dx);
      expect(mid.toString(), contains('CardSlot'));
    });

    test('heights and focus', () {
      expect(CardStackMath.cardHeight(343), closeTo(216.3, 0.1));
      expect(CardStackMath.pileHeight(1, 200), 200);
      expect(CardStackMath.pileHeight(3, 200), 200 + 2 * CardStackMath.peek);
      expect(CardStackMath.pileHeight(50, 200), 200 + 3 * CardStackMath.peek);
      expect(CardStackMath.pileHeight(0, 200), 200);
      expect(CardStackMath.focusedFor(1.4, 3), 1);
      expect(CardStackMath.focusedFor(1.6, 3), 2);
      expect(CardStackMath.focusedFor(9, 3), 2);
      expect(CardStackMath.focusedFor(-1, 3), 0);
      expect(CardStackMath.focusedFor(1, 0), 0);
    });
  });

  group('CardStackCubit', () {
    blocTest<CardStackCubit, CardStackState>(
      'fan out, flip, focus and collapse',
      build: CardStackCubit.new,
      act: (c) => c
        ..cardsChanged(3)
        ..fanOut()
        ..fanOut()
        ..flip('a')
        ..flip('b')
        ..flip('a')
        ..focus(2)
        ..focus(2)
        ..collapse(),
      expect: () => const [
        CardStackState(count: 3),
        CardStackState(count: 3, fanned: true),
        CardStackState(count: 3, fanned: true, flipped: {'a'}),
        CardStackState(count: 3, fanned: true, flipped: {'a', 'b'}),
        CardStackState(count: 3, fanned: true, flipped: {'b'}),
        CardStackState(count: 3, fanned: true, focused: 2),
        CardStackState(count: 3, focused: 2),
      ],
    );

    blocTest<CardStackCubit, CardStackState>(
      'toggle and unflipAll',
      build: CardStackCubit.new,
      act: (c) => c
        ..cardsChanged(2)
        ..toggle()
        ..flip('x')
        ..unflipAll()
        ..unflipAll()
        ..toggle(),
      expect: () => const [
        CardStackState(count: 2),
        CardStackState(count: 2, fanned: true),
        CardStackState(count: 2, fanned: true, flipped: {'x'}),
        CardStackState(count: 2, fanned: true),
        CardStackState(count: 2),
      ],
    );

    blocTest<CardStackCubit, CardStackState>(
      'a new card becomes the focused, fanned card; removals clamp',
      build: CardStackCubit.new,
      act: (c) => c
        ..cardsChanged(2)
        ..focus(1)
        ..cardsChanged(3, focusNewest: true)
        ..cardsChanged(1)
        ..cardsChanged(0),
      expect: () => const [
        CardStackState(count: 2),
        CardStackState(count: 2, focused: 1),
        CardStackState(count: 3, fanned: true),
        CardStackState(count: 1, fanned: true),
        CardStackState(),
      ],
    );

    test('focus on an empty stack is ignored; isFlipped', () {
      final c = CardStackCubit()..focus(3);
      expect(c.state, const CardStackState());
      c
        ..cardsChanged(1)
        ..flip('a');
      expect(c.state.isFlipped('a'), isTrue);
      expect(c.state.isFlipped('b'), isFalse);
      unawaited(c.close());
    });
  });
}
