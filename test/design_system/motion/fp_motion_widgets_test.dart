import 'dart:ui' show Tristate;

import 'package:animations/animations.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/pump.dart';

double _dx(WidgetTester tester, Finder finder) {
  final transforms = tester.widgetList<Transform>(
    find.descendant(of: finder, matching: find.byType(Transform)),
  );
  return transforms.first.transform.getTranslation().x;
}

double _dy(WidgetTester tester, Finder finder) {
  final transforms = tester.widgetList<Transform>(
    find.descendant(of: finder, matching: find.byType(Transform)),
  );
  return transforms.first.transform.getTranslation().y;
}

void main() {
  group('FpPressable', () {
    testWidgets('scales on press, springs back, haptic, button semantics', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      var pressed = 0;
      await pumpFp(
        tester,
        FpPressable(
          onPressed: () => pressed++,
          semanticLabel: 'Card',
          haptics: haptics,
          depth: 6,
          child: const SizedBox(width: 100, height: 100),
        ),
      );
      final node = tester.getSemantics(find.byType(FpPressable));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, 'Card');
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FpPressable)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final scale = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(FpPressable),
              matching: find.byType(Transform),
            ),
          )
          .last
          .transform
          .entry(0, 0);
      expect(scale, closeTo(0.96, 0.001));
      expect(_dx(tester, find.byType(FpPressable)), closeTo(6, 0.001));
      expect(haptics.calls, [HapticType.light]);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(_dx(tester, find.byType(FpPressable)), closeTo(0, 0.001));
    });

    testWidgets('reduce motion: no scale, still fires', (tester) async {
      var pressed = 0;
      await pumpFp(
        tester,
        FpPressable(
          onPressed: () => pressed++,
          child: const SizedBox(width: 100, height: 100),
        ),
        reduceMotion: true,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FpPressable)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_dx(tester, find.byType(FpPressable)), 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pressed, 1);
    });

    testWidgets('disabled and tiny children still get a 48 dp target', (
      tester,
    ) async {
      await pumpFp(
        tester,
        const FpPressable(enabled: false, child: SizedBox(width: 8, height: 8)),
      );
      final size = tester.getSize(find.byType(FpPressable));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.byType(FpPressable)).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
    });

    testWidgets('long press fires', (tester) async {
      var long = 0;
      await pumpFp(
        tester,
        FpPressable(
          onLongPress: () => long++,
          haptic: null,
          child: const SizedBox(width: 60, height: 60),
        ),
      );
      await tester.longPress(find.byType(FpPressable));
      await tester.pumpAndSettle();
      expect(long, 1);
    });
  });

  group('FpEntrance / FpStaggeredEntrance', () {
    testWidgets('slides by pixels and fades in', (tester) async {
      await pumpFp(
        tester,
        const FpEntrance(child: SizedBox(width: 10, height: 10)),
      );
      final fade = find.descendant(
        of: find.byType(FpEntrance),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(fade).opacity.value, 0);
      expect(_dy(tester, find.byType(FpEntrance)), closeTo(24, 0.001));
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _dy(tester, find.byType(FpEntrance));
      expect(mid, lessThan(24));
      expect(mid, greaterThan(0));
      await tester.pumpAndSettle();
      expect(_dy(tester, find.byType(FpEntrance)), closeTo(0, 0.001));
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    });

    testWidgets('delay, scale and fade=false', (tester) async {
      await pumpFp(
        tester,
        const FpEntrance(
          delay: Duration(milliseconds: 200),
          scaleFrom: 0.8,
          fade: false,
          child: SizedBox(width: 10, height: 10),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FpEntrance),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_dy(tester, find.byType(FpEntrance)), closeTo(24, 0.001));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_dy(tester, find.byType(FpEntrance)), lessThan(24));
      await tester.pumpAndSettle();
      expect(find.byType(Transform), findsWidgets);
    });

    testWidgets('disposing before the delay ends is safe', (tester) async {
      await pumpFp(
        tester,
        const FpEntrance(
          delay: Duration(seconds: 1),
          child: SizedBox(width: 10, height: 10),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce motion: fast fade, no translation', (tester) async {
      await pumpFp(
        tester,
        const FpEntrance(child: SizedBox(width: 10, height: 10)),
        reduceMotion: true,
      );
      expect(
        find.descendant(
          of: find.byType(FpEntrance),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      await tester.pump(FpMotion.fast);
      await tester.pumpAndSettle();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('stagger wraps every child and caps the total time', (
      tester,
    ) async {
      await pumpFp(
        tester,
        FpStaggeredEntrance(
          children: [
            for (var i = 0; i < 50; i++) SizedBox(height: 4, key: ValueKey(i)),
          ],
        ),
      );
      expect(find.byType(FpEntrance), findsNWidgets(50));
      final total = fpStaggerTotal(50);
      expect(total, lessThanOrEqualTo(const Duration(milliseconds: 900)));
      await tester.pump(total + const Duration(milliseconds: 1));
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('custom builder receives the wrapped children', (tester) async {
      await pumpFp(
        tester,
        FpStaggeredEntrance(
          builder: (context, children) => Row(children: children),
          children: const [Text('a'), Text('b')],
        ),
      );
      expect(find.byType(Row), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
    });
  });

  group('FpParallax', () {
    testWidgets('translates against the scroll offset', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpFp(
        tester,
        Stack(
          children: [
            FpParallax(
              controller: controller,
              child: const SizedBox(key: ValueKey('bg'), height: 50),
            ),
            ListView(
              controller: controller,
              children: [
                for (var i = 0; i < 30; i++) const SizedBox(height: 100),
              ],
            ),
          ],
        ),
        scaffold: false,
      );
      expect(_dy(tester, find.byType(FpParallax)), 0);
      controller.jumpTo(200);
      await tester.pump();
      expect(_dy(tester, find.byType(FpParallax)), -100);
    });

    testWidgets('horizontal axis, clamp and reduce motion', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpFp(
        tester,
        Stack(
          children: [
            FpParallax(
              controller: controller,
              axis: Axis.horizontal,
              clamp: 30,
              child: const SizedBox(height: 50),
            ),
            ListView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < 30; i++) const SizedBox(width: 100),
              ],
            ),
          ],
        ),
        scaffold: false,
      );
      controller.jumpTo(500);
      await tester.pump();
      expect(_dx(tester, find.byType(FpParallax)), -30);
      await pumpFp(
        tester,
        FpParallax(controller: controller, child: const SizedBox()),
        reduceMotion: true,
      );
      expect(
        find.descendant(
          of: find.byType(FpParallax),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
    });
  });

  group('FpShake', () {
    testWidgets('shakes on controller.shake and settles at zero', (
      tester,
    ) async {
      final controller = FpShakeController();
      addTearDown(controller.dispose);
      await pumpFp(
        tester,
        FpShake(controller: controller, child: const SizedBox(height: 10)),
      );
      expect(_dx(tester, find.byType(FpShake)), 0);
      controller.shake();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_dx(tester, find.byType(FpShake)), isNot(0));
      await tester.pumpAndSettle();
      expect(_dx(tester, find.byType(FpShake)), 0);
    });

    testWidgets('reduce motion ignores shakes; controller swap works', (
      tester,
    ) async {
      final a = FpShakeController();
      final b = FpShakeController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await pumpFp(
        tester,
        FpShake(controller: a, child: const SizedBox(height: 10)),
        reduceMotion: true,
      );
      a.shake();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_dx(tester, find.byType(FpShake)), 0);
      await pumpFp(
        tester,
        FpShake(controller: b, child: const SizedBox(height: 10)),
      );
      b.shake();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(_dx(tester, find.byType(FpShake)), isNot(0));
      await tester.pumpAndSettle();
    });
  });

  group('FpPulse', () {
    testWidgets('pulses a finite number of times then stops', (tester) async {
      await pumpFp(
        tester,
        const FpPulse(
          pulses: 2,
          duration: Duration(milliseconds: 100),
          child: SizedBox(width: 10, height: 10),
        ),
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      await tester.pump(const Duration(milliseconds: 50));
      final pulseScale = find.descendant(
        of: find.byType(FpPulse),
        matching: find.byType(ScaleTransition),
      );
      final scale = tester.widget<ScaleTransition>(pulseScale);
      expect(scale.scale.value, greaterThan(1));
      // First pulse ends; the second starts on the next frame and ends 100 ms
      // later; then no more.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 1));
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      expect(tester.widget<ScaleTransition>(pulseScale).scale.value, 1);
    });

    testWidgets('reduce motion never starts; active=false stops', (
      tester,
    ) async {
      await pumpFp(
        tester,
        const FpPulse(child: SizedBox(width: 10, height: 10)),
        reduceMotion: true,
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
      await pumpFp(
        tester,
        const FpPulse(child: SizedBox(width: 10, height: 10)),
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      await pumpFp(
        tester,
        const FpPulse(active: false, child: SizedBox(width: 10, height: 10)),
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      await pumpFp(
        tester,
        const FpPulse(child: SizedBox(width: 10, height: 10)),
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      await tester.pumpAndSettle();
    });
  });

  group('FpConfetti', () {
    testWidgets('bursts once per burst() and stops', (tester) async {
      final controller = FpConfettiController();
      addTearDown(controller.dispose);
      await pumpFp(
        tester,
        FpConfetti(controller: controller, child: const SizedBox.expand()),
        scaffold: false,
      );
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      controller.burst();
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      expect(controller.bursts, 1);
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
    });

    testWidgets('autoPlay bursts after the first frame; reduce motion skips', (
      tester,
    ) async {
      final a = FpConfettiController();
      final b = FpConfettiController();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await pumpFp(tester, FpConfetti(controller: a, autoPlay: true));
      await tester.pump();
      expect(a.bursts, 1);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await pumpFp(
        tester,
        FpConfetti(controller: b, autoPlay: true),
        reduceMotion: true,
      );
      await tester.pump();
      expect(b.bursts, 1);
      expect(SchedulerBinding.instance.transientCallbackCount, 0);
      // Swapping controllers re-subscribes.
      await pumpFp(tester, FpConfetti(controller: a));
      await pumpFp(tester, FpConfetti(controller: b));
      b.burst();
      await tester.pump();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      await tester.pumpAndSettle();
    });
  });

  group('FpPageTransitions', () {
    GoRouter router(FpTransitionKind kind, {bool reduce = false}) {
      CustomTransitionPage<void> page(Widget child, LocalKey key) =>
          switch (kind) {
            FpTransitionKind.sharedAxisX => FpPageTransitions.sharedAxisX(
              child,
              key: key,
            ),
            FpTransitionKind.sharedAxisY => FpPageTransitions.sharedAxisY(
              child,
              key: key,
            ),
            FpTransitionKind.sharedAxisZ => FpPageTransitions.sharedAxisZ(
              child,
              key: key,
            ),
            FpTransitionKind.fadeThrough => FpPageTransitions.fadeThrough(
              child,
              key: key,
            ),
          };
      return GoRouter(
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                page(const Text('home'), state.pageKey),
          ),
          GoRoute(
            path: '/next',
            pageBuilder: (context, state) =>
                page(const Text('next'), state.pageKey),
          ),
        ],
      );
    }

    for (final kind in FpTransitionKind.values) {
      testWidgets('${kind.name} builds a go_router page that navigates', (
        tester,
      ) async {
        final r = router(kind);
        addTearDown(r.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: FpTheme.dark(), routerConfig: r),
        );
        expect(find.text('home'), findsOneWidget);
        r.go('/next');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final expected = kind == FpTransitionKind.fadeThrough
            ? FadeThroughTransition
            : SharedAxisTransition;
        expect(find.byType(expected), findsWidgets);
        await tester.pumpAndSettle();
        expect(find.text('next'), findsOneWidget);
        expect(find.text('home'), findsNothing);
      });
    }

    testWidgets('reduce motion falls back to a plain fade', (tester) async {
      final r = router(FpTransitionKind.sharedAxisX);
      addTearDown(r.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: FpTheme.dark(),
          routerConfig: r,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      );
      r.go('/next');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SharedAxisTransition), findsNothing);
      expect(find.byType(FadeTransition), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
    });

    test('pages carry the screen duration and metadata', () {
      final page = FpPageTransitions.sharedAxisY<int>(
        const SizedBox(),
        key: const ValueKey('k'),
        name: 'n',
        arguments: 1,
        restorationId: 'r',
      );
      expect(page.transitionDuration, FpMotion.screen);
      expect(page.reverseTransitionDuration, FpMotion.emphasized);
      expect(page.name, 'n');
      expect(page.arguments, 1);
      expect(page.restorationId, 'r');
    });
  });

  group('FpHero', () {
    testWidgets('flies between routes with the shared shuttle', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: FpTheme.dark(),
          home: const Scaffold(
            body: FpHero(
              tag: 'card',
              child: SizedBox(width: 50, height: 50, child: Text('from')),
            ),
          ),
        ),
      );
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Center(
              child: FpHero(
                tag: 'card',
                child: SizedBox(width: 200, height: 200, child: Text('to')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-flight the shuttle shows both ends inside a transparent Material.
      expect(find.text('from'), findsWidgets);
      expect(find.text('to'), findsWidgets);
      expect(
        tester
            .widgetList<Material>(find.byType(Material))
            .where((m) => m.type == MaterialType.transparency),
        isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final hero = tester.widget<Hero>(find.byType(Hero).first);
      expect(hero.flightShuttleBuilder, FpHero.flightShuttleBuilder);
      expect(
        FpHero.createRectTween(Rect.zero, const Rect.fromLTWH(0, 0, 1, 1)),
        isA<MaterialRectArcTween>(),
      );
      // Pop so the reverse flight also runs through the shuttle.
      navigatorKey.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('from'), findsOneWidget);
    });
  });
}
