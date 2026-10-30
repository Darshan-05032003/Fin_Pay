import 'dart:ui' show Tristate;

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

const _items = [
  FpBottomNavItem(icon: Icons.home_outlined, label: 'Home'),
  FpBottomNavItem(icon: Icons.bar_chart_outlined, label: 'Stats'),
  FpBottomNavItem(icon: Icons.credit_card_outlined, label: 'Cards'),
  FpBottomNavItem(icon: Icons.person_outline, label: 'Profile'),
];

void main() {
  group('FpBottomNav.indicatorLeft', () {
    test('divides the width evenly', () {
      expect(FpBottomNav.indicatorLeft(0, 4, 400), 0);
      expect(FpBottomNav.indicatorLeft(1, 4, 400), 100);
      expect(FpBottomNav.indicatorLeft(3, 4, 400), 300);
      expect(FpBottomNav.indicatorLeft(1, 2, 300), 150);
    });
  });

  group('FpBottomNav', () {
    Future<void> pumpNav(
      WidgetTester tester, {
      required int index,
      required ValueChanged<int> onSelected,
      ValueChanged<int>? onReselected,
      FakeHapticService? haptics,
      bool reduceMotion = false,
    }) async {
      await pumpFp(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: FpBottomNav(
            items: _items,
            currentIndex: index,
            onSelected: onSelected,
            onReselected: onReselected,
            haptics: haptics,
          ),
        ),
        reduceMotion: reduceMotion,
      );
    }

    testWidgets('every tab is a labelled, ≥ 48 dp button; one is selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpNav(tester, index: 2, onSelected: (_) {});
      for (final item in _items) {
        final tab = find.ancestor(
          of: find.text(item.label),
          matching: find.byType(FpPressable),
        );
        final node = tester.getSemantics(tab);
        expect(node.flagsCollection.isButton, isTrue, reason: item.label);
        expect(node.label, item.label);
        expect(
          node.flagsCollection.isSelected,
          item.label == 'Cards' ? Tristate.isTrue : Tristate.isFalse,
          reason: item.label,
        );
        expect(
          tester
              .getSize(
                find.ancestor(
                  of: find.text(item.label),
                  matching: find.byType(FpPressable),
                ),
              )
              .height,
          greaterThanOrEqualTo(FpSpacing.minTapTarget),
        );
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('tap selects, plays a selection haptic; re-tap reselects', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      final selected = <int>[];
      final reselected = <int>[];
      await pumpNav(
        tester,
        index: 0,
        onSelected: selected.add,
        onReselected: reselected.add,
        haptics: haptics,
      );
      await tester.tap(find.text('Cards'));
      await tester.pump();
      expect(selected, [2]);
      expect(haptics.calls, [HapticType.selection]);
      await tester.tap(find.text('Home'));
      await tester.pump();
      expect(selected, [2]);
      expect(reselected, [0]);
    });

    testWidgets('indicator slides to the selected tab', (tester) async {
      var index = 0;
      late StateSetter set;
      await pumpFp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return Align(
              alignment: Alignment.bottomCenter,
              child: FpBottomNav(
                items: _items,
                currentIndex: index,
                onSelected: (i) => setState(() => index = i),
              ),
            );
          },
        ),
      );
      final indicator = find.byKey(const ValueKey('fp-bottom-nav-indicator'));
      final width = tester.getSize(find.byType(FpBottomNav)).width;
      expect(tester.getTopLeft(indicator).dx, 0);
      set(() => index = 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getTopLeft(indicator).dx;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(width * 0.75));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getTopLeft(indicator).dx, closeTo(width * 0.75, 0.01));
    });

    testWidgets('reduce motion: the indicator jumps', (tester) async {
      var index = 0;
      late StateSetter set;
      await pumpFp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return Align(
              alignment: Alignment.bottomCenter,
              child: FpBottomNav(
                items: _items,
                currentIndex: index,
                onSelected: (i) => setState(() => index = i),
              ),
            );
          },
        ),
        reduceMotion: true,
      );
      final width = tester.getSize(find.byType(FpBottomNav)).width;
      set(() => index = 1);
      await tester.pump();
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('fp-bottom-nav-indicator')))
            .dx,
        closeTo(width * 0.25, 0.01),
      );
    });

    testWidgets('renders at 1.3× without overflow', (tester) async {
      await pumpFp(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: FpBottomNav(
            items: _items,
            currentIndex: 1,
            onSelected: (_) {},
          ),
        ),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
