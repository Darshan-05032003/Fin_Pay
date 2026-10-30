import 'dart:ui' show Tristate;

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump.dart';

void main() {
  group('FpTextField', () {
    testWidgets('renders label, hint, helper and passes text through', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? changed;
      await pumpFp(
        tester,
        FpTextField(
          controller: controller,
          label: 'Name',
          hint: 'Your name',
          helperText: 'As on your card',
          onChanged: (v) => changed = v,
        ),
      );
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('Your name'), findsOneWidget);
      expect(find.text('As on your card'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Aarav');
      expect(controller.text, 'Aarav');
      expect(changed, 'Aarav');
      final node = tester.getSemantics(find.byType(TextField));
      expect(node.flagsCollection.isTextField, isTrue);
    });

    testWidgets('focus turns the border to accent with a glow', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpFp(tester, FpTextField(focusNode: focus, hint: 'x'));
      AnimatedContainer box() =>
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      BoxDecoration deco() => box().decoration! as BoxDecoration;
      expect(deco().boxShadow, isEmpty);
      expect(deco().border!.top.color, FpColors.border);
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(deco().boxShadow, isNotEmpty);
      expect(deco().border!.top.color, FpColors.accent);
      expect(deco().border!.top.width, 2);
      focus.unfocus();
      await tester.pumpAndSettle();
      expect(deco().boxShadow, isEmpty);
    });

    testWidgets('error state shows text, shakes and plays error haptic', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      Widget build(String? error) =>
          FpTextField(hint: 'UPI', errorText: error, haptics: haptics);
      await pumpFp(tester, build(null));
      expect(haptics.calls, isEmpty);
      await pumpFp(tester, build('Invalid UPI ID'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Invalid UPI ID'), findsOneWidget);
      expect(haptics.calls, [HapticType.error]);
      // Mid-shake the box is displaced horizontally.
      final transform = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(FpShake),
          matching: find.byType(Transform),
        ),
      );
      final dx = transform.first.transform.getTranslation().x;
      expect(dx, isNot(0));
      await tester.pumpAndSettle();
      // Same error again: no new shake. New error: shakes again.
      await pumpFp(tester, build('Invalid UPI ID'));
      await tester.pumpAndSettle();
      expect(haptics.calls.length, 1);
      await pumpFp(tester, build('Still invalid'));
      await tester.pumpAndSettle();
      expect(haptics.calls.length, 2);
      final deco =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;
      expect(deco.border!.top.color, FpColors.alert);
    });

    testWidgets(
      'reduce motion: error shows without shake, haptic still fires',
      (tester) async {
        final haptics = fakeHaptics();
        await pumpFp(
          tester,
          FpTextField(hint: 'x', haptics: haptics),
          reduceMotion: true,
        );
        await pumpFp(
          tester,
          FpTextField(hint: 'x', errorText: 'Bad', haptics: haptics),
          reduceMotion: true,
        );
        await tester.pump(const Duration(milliseconds: 100));
        final transform = tester.widgetList<Transform>(
          find.descendant(
            of: find.byType(FpShake),
            matching: find.byType(Transform),
          ),
        );
        expect(transform.first.transform.getTranslation().x, 0);
        expect(haptics.calls, [HapticType.error]);
        expect(find.text('Bad'), findsOneWidget);
      },
    );

    testWidgets('obscure toggle shows and hides the password', (tester) async {
      await pumpFp(
        tester,
        const FpTextField(hint: 'Password', obscureText: true),
      );
      TextField field() => tester.widget<TextField>(find.byType(TextField));
      expect(field().obscureText, isTrue);
      expect(field().enableSuggestions, isFalse);
      expect(field().autocorrect, isFalse);
      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(field().obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);
      final toggle = tester.getSize(find.byType(IconButton));
      expect(toggle.width, greaterThanOrEqualTo(48));
      expect(toggle.height, greaterThanOrEqualTo(48));
    });

    testWidgets('prefix, suffix and inputFormatters pass through', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpFp(
        tester,
        FpTextField(
          controller: controller,
          prefix: const Icon(Icons.phone),
          suffix: const Icon(Icons.check),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
        ),
      );
      expect(find.byIcon(Icons.phone), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.enterText(find.byType(TextField), '12ab34');
      expect(controller.text, '1234');
      await tester.enterText(find.byType(TextField), '123456789');
      expect(controller.text.length, lessThanOrEqualTo(4));
    });

    testWidgets('disabled field is not editable', (tester) async {
      await pumpFp(tester, const FpTextField(hint: 'x', enabled: false));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('survives hostile input: huge, unicode, RTL, emoji', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpFp(tester, FpTextField(controller: controller, hint: 'x'));
      final hostile = [
        'a' * 10000,
        '𝔘𝔫𝔦𝔠𝔬𝔡𝔢 ﷽ ' * 50,
        '\u202Eevil\u202C ' * 20,
        '🧨🔥💸' * 300,
        '\u0000​﻿',
      ];
      for (final text in hostile) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(controller.text, text);
      }
    });

    testWidgets('swapping focus nodes keeps the listener working', (
      tester,
    ) async {
      final a = FocusNode();
      final b = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await pumpFp(tester, FpTextField(focusNode: a, hint: 'x'));
      await pumpFp(tester, FpTextField(focusNode: b, hint: 'x'));
      b.requestFocus();
      await tester.pumpAndSettle();
      final deco =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;
      expect(deco.border!.top.color, FpColors.accent);
    });
  });

  group('FpChip', () {
    testWidgets('selected and idle states, haptic and callback', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      bool? result;
      await pumpFp(
        tester,
        FpChip(label: 'Food', onSelected: (v) => result = v, haptics: haptics),
      );
      await tester.tap(find.byType(FpChip));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(haptics.calls, [HapticType.selection]);
      await pumpFp(
        tester,
        FpChip(label: 'Food', selected: true, onSelected: (v) => result = v),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.byType(FpChip));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.label, 'Food');
      await tester.tap(find.byType(FpChip));
      expect(result, isFalse);
      final size = tester.getSize(find.byType(FpChip));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('disabled chip ignores taps and shows no haptic', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      var taps = 0;
      await pumpFp(
        tester,
        FpChip(
          label: 'Off',
          enabled: false,
          leadingIcon: Icons.star,
          onSelected: (_) => taps++,
          haptics: haptics,
        ),
      );
      await tester.tap(find.byType(FpChip));
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(haptics.calls, isEmpty);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('reduce motion: AnimatedContainer uses zero duration', (
      tester,
    ) async {
      await pumpFp(
        tester,
        FpChip(label: 'x', onSelected: (_) {}),
        reduceMotion: true,
      );
      final anim = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect(anim.duration, Duration.zero);
    });
  });

  group('FpToggle', () {
    testWidgets('toggles with haptic, semantics and 48 dp target', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      bool? value;
      await pumpFp(
        tester,
        FpToggle(
          value: false,
          onChanged: (v) => value = v,
          semanticLabel: 'Haptics',
          haptics: haptics,
        ),
      );
      final size = tester.getSize(find.byType(FpToggle));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      final node = tester.getSemantics(find.byType(FpToggle));
      expect(node.label, 'Haptics');
      expect(node.flagsCollection.isToggled, Tristate.isFalse);
      await tester.tap(find.byType(FpToggle));
      expect(value, isTrue);
      expect(haptics.calls, [HapticType.light]);
    });

    testWidgets('thumb springs from left to right on value change', (
      tester,
    ) async {
      await pumpFp(tester, FpToggle(value: false, onChanged: (_) {}));
      Positioned thumb() => tester.widget<Positioned>(find.byType(Positioned));
      final left = thumb().left!;
      await pumpFp(tester, FpToggle(value: true, onChanged: (_) {}));
      await tester.pump(const Duration(milliseconds: 40));
      final mid = thumb().left!;
      expect(mid, greaterThan(left));
      await tester.pumpAndSettle();
      final right = thumb().left!;
      expect(right, greaterThan(mid));
      expect(
        tester.getSemantics(find.byType(FpToggle)).flagsCollection.isToggled,
        Tristate.isTrue,
      );
    });

    testWidgets('reduce motion: thumb jumps instantly', (tester) async {
      await pumpFp(
        tester,
        FpToggle(value: false, onChanged: (_) {}),
        reduceMotion: true,
      );
      await pumpFp(
        tester,
        FpToggle(value: true, onChanged: (_) {}),
        reduceMotion: true,
      );
      await tester.pump();
      final thumb = tester.widget<Positioned>(find.byType(Positioned));
      expect(thumb.left, closeTo(4 + (56 - 24 - 8), 0.01));
    });

    testWidgets('disabled toggle does nothing', (tester) async {
      await pumpFp(tester, const FpToggle(value: true));
      await tester.tap(find.byType(FpToggle));
      expect(
        tester.getSemantics(find.byType(FpToggle)).flagsCollection.isEnabled,
        Tristate.isFalse,
      );
    });
  });

  group('FpSegmentedControl', () {
    testWidgets('selects, animates the indicator and plays a haptic', (
      tester,
    ) async {
      final haptics = fakeHaptics();
      int? picked;
      await pumpFp(
        tester,
        SizedBox(
          width: 300,
          child: FpSegmentedControl(
            segments: const ['Week', 'Month', 'Year'],
            selectedIndex: 0,
            onChanged: (i) => picked = i,
            haptics: haptics,
          ),
        ),
      );
      await tester.tap(find.text('Year'));
      expect(picked, 2);
      expect(haptics.calls, [HapticType.selection]);
      await tester.tap(find.text('Week'));
      expect(haptics.calls.length, 1, reason: 'same segment: no haptic');
      final node = tester.getSemantics(find.text('Week'));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isButton, isTrue);
      AnimatedPositioned indicator() =>
          tester.widget<AnimatedPositioned>(find.byType(AnimatedPositioned));
      expect(indicator().left, 0);
      await pumpFp(
        tester,
        SizedBox(
          width: 300,
          child: FpSegmentedControl(
            segments: const ['Week', 'Month', 'Year'],
            selectedIndex: 2,
            onChanged: (i) => picked = i,
          ),
        ),
      );
      expect(indicator().left, closeTo(200, 0.01));
      expect(indicator().duration, FpMotion.standard);
      expect(tester.getSize(find.byType(FpSegmentedControl)).height, 48);
    });

    testWidgets('reduce motion uses a zero duration; disabled has no taps', (
      tester,
    ) async {
      var changed = 0;
      await pumpFp(
        tester,
        FpSegmentedControl(
          segments: const ['A', 'B'],
          selectedIndex: 0,
          onChanged: (_) => changed++,
        ),
        reduceMotion: true,
      );
      expect(
        tester
            .widget<AnimatedPositioned>(find.byType(AnimatedPositioned))
            .duration,
        Duration.zero,
      );
      await pumpFp(
        tester,
        FpSegmentedControl(segments: const ['A', 'B'], selectedIndex: 0),
      );
      await tester.tap(find.text('B'));
      expect(changed, 0);
    });
  });

  group('FpPageIndicator', () {
    testWidgets('active dot is wider and semantics say the page', (
      tester,
    ) async {
      await pumpFp(tester, const FpPageIndicator(count: 3, index: 1));
      await tester.pumpAndSettle();
      final dots = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      expect(dots.length, 3);
      expect(
        tester.getSemantics(find.byType(FpPageIndicator)).label,
        'Page 2 of 3',
      );
      final sizes = tester.getSize(find.byType(AnimatedContainer).at(1)).width;
      expect(sizes, 24);
      expect(tester.getSize(find.byType(AnimatedContainer).at(0)).width, 8);
    });

    testWidgets('reduce motion morph is instant', (tester) async {
      await pumpFp(
        tester,
        const FpPageIndicator(count: 2, index: 0),
        reduceMotion: true,
      );
      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
            .duration,
        Duration.zero,
      );
    });
  });
}
