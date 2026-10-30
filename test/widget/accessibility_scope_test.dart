import 'package:fin_pay/app.dart';
import 'package:fin_pay/core/settings/app_settings.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/core/settings/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySettingsRepository repo;
  late SettingsCubit cubit;

  setUp(() {
    repo = InMemorySettingsRepository();
    cubit = SettingsCubit(repo);
  });

  tearDown(() => cubit.close());

  /// Pumps [AccessibilityScope] under a MediaQuery with [systemScale] and
  /// returns the MediaQueryData seen by the child.
  Future<MediaQueryData> pumpWith(
    WidgetTester tester, {
    required double systemScale,
    bool systemDisableAnimations = false,
  }) async {
    late MediaQueryData seen;
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(systemScale),
            disableAnimations: systemDisableAnimations,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: AccessibilityScope(
              child: Builder(
                builder: (context) {
                  seen = MediaQuery.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
    return seen;
  }

  group('text scale clamp', () {
    for (final (input, expected) in [(1.0, 1.0), (1.3, 1.3), (2.0, 1.3)]) {
      testWidgets('system $input → effective $expected', (tester) async {
        final data = await pumpWith(tester, systemScale: input);
        expect(data.textScaler.scale(10), closeTo(10 * expected, 1e-9));
        expect(data.textScaler.scale(100), lessThanOrEqualTo(130));
      });
    }

    testWidgets('kMaxTextScale is 1.3', (tester) async {
      expect(kMaxTextScale, 1.3);
    });

    testWidgets('a 24 px Text renders at most 1.3× under scale 3.0', (
      tester,
    ) async {
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            builder: (context, child) => AccessibilityScope(child: child!),
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(3)),
              child: AccessibilityScope(
                child: Center(
                  child: Text('₹1,23,456.78', style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.text('₹1,23,456.78'));
      // Line height for a 24 px font at 1.3× is ~31 px; at 3× it would be
      // ~72 px.
      expect(size.height, lessThan(40));
    });
  });

  group('reduce motion', () {
    testWidgets('setting on → MediaQuery.disableAnimations is true', (
      tester,
    ) async {
      await cubit.setReduceMotion(enabled: true);
      final data = await pumpWith(tester, systemScale: 1);
      expect(data.disableAnimations, isTrue);
    });

    testWidgets('setting off keeps the system value', (tester) async {
      var data = await pumpWith(tester, systemScale: 1);
      expect(data.disableAnimations, isFalse);
      data = await pumpWith(
        tester,
        systemScale: 1,
        systemDisableAnimations: true,
      );
      expect(data.disableAnimations, isTrue);
    });

    testWidgets('toggling the setting rebuilds the scope live', (tester) async {
      late BuildContext childContext;
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: AccessibilityScope(
                child: Builder(
                  builder: (context) {
                    childContext = context;
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(MediaQuery.disableAnimationsOf(childContext), isFalse);
      await cubit.setReduceMotion(enabled: true);
      await tester.pump();
      expect(MediaQuery.disableAnimationsOf(childContext), isTrue);
      expect(repo.settings, const AppSettings(reduceMotion: true));
    });
  });
}
