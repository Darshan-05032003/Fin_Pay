import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FpContrast', () {
    test('black on white is 21:1 and identical colours are 1:1', () {
      expect(
        FpContrast.ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(FpContrast.ratio(FpColors.accent, FpColors.accent), 1);
    });

    test('is symmetric', () {
      expect(
        FpContrast.ratio(FpColors.accent, FpColors.background),
        FpContrast.ratio(FpColors.background, FpColors.accent),
      );
    });
  });

  group('FpColors WCAG AA', () {
    for (final (name, fg, bg) in FpColors.textSurfacePairs) {
      test('$name ≥ 4.5:1', () {
        final ratio = FpContrast.ratio(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(FpContrast.aaNormal),
          reason: '$name is ${ratio.toStringAsFixed(2)}:1',
        );
      });
    }

    test('surfaces separate from the background (≥ 1.08:1 each step)', () {
      const ramp = [
        FpColors.background,
        FpColors.surface,
        FpColors.surfaceRaised,
        FpColors.surfaceHigh,
      ];
      for (var i = 1; i < ramp.length; i++) {
        expect(
          FpContrast.ratio(ramp[i], ramp[i - 1]),
          greaterThanOrEqualTo(1.08),
          reason: 'step $i',
        );
        expect(
          FpContrast.luminance(ramp[i]),
          greaterThan(FpContrast.luminance(ramp[i - 1])),
        );
      }
      // The old theme had 1.02:1 between page and card.
      expect(
        FpContrast.ratio(FpColors.surface, FpColors.background),
        greaterThanOrEqualTo(1.1),
      );
      expect(
        FpContrast.ratio(FpColors.surfaceHigh, FpColors.background),
        greaterThanOrEqualTo(1.35),
      );
    });

    test('border is visible on every surface (≥ 1.3:1)', () {
      for (final surface in FpColors.surfaces.values) {
        expect(
          FpContrast.ratio(FpColors.borderStrong, surface),
          greaterThanOrEqualTo(1.3),
        );
      }
    });

    test('every token colour is opaque except the scrim', () {
      for (final entry in const FpColorScheme().all.entries) {
        if (entry.key == 'scrim') continue;
        expect(entry.value.a, 1, reason: entry.key);
      }
      expect(FpColors.scrim.a, lessThan(1));
    });
  });

  group('spacing, radii, depth', () {
    test('spacing scale is 4/8/12/16/24/32/48', () {
      expect(FpSpacing.scale, [4, 8, 12, 16, 24, 32, 48]);
      expect(FpSpacing.minTapTarget, 48);
    });

    test('radii stay sharp (≤ 12) except the pill', () {
      for (final r in [
        FpRadii.none,
        FpRadii.xs,
        FpRadii.sm,
        FpRadii.md,
        FpRadii.lg,
      ]) {
        expect(r, lessThanOrEqualTo(12));
      }
      expect(FpRadii.pill, greaterThan(100));
    });

    test('depth scale ascends', () {
      const s = FpDepth.scale;
      for (var i = 1; i < s.length; i++) {
        expect(s[i], greaterThan(s[i - 1]));
      }
    });

    test('edge faces differ from each other and from the face', () {
      for (final edge in [
        FpEdge.accent,
        FpEdge.success,
        FpEdge.alert,
        FpEdge.popWhite,
        FpEdge.surface,
        FpEdge.surfaceRaised,
        FpEdge.disabled,
      ]) {
        expect(edge.right, isNot(edge.bottom));
      }
      expect(FpEdge.accent.right, isNot(FpColors.accent));
    });
  });

  group('typography', () {
    test('display styles use Instrument Serif, UI styles use Manrope', () {
      for (final entry in FpTypography.all.entries) {
        final expected = entry.key.startsWith('display')
            ? FpTypography.displayFamily
            : FpTypography.uiFamily;
        expect(entry.value.fontFamily, expected, reason: entry.key);
      }
    });

    test('scale descends from display to caption', () {
      const t = FpTypography.all;
      double size(String name) => t[name]!.fontSize!;
      expect(size('displayLarge'), greaterThan(size('displayMedium')));
      expect(size('displayMedium'), greaterThan(size('displaySmall')));
      expect(size('headline'), greaterThan(size('title')));
      expect(size('title'), greaterThan(size('body')));
      expect(size('body'), greaterThan(size('caption')));
      expect(size('caption'), greaterThanOrEqualTo(11));
    });

    test('amount styles use tabular figures', () {
      expect(FpTypography.displayLarge.fontFeatures, isNotEmpty);
      expect(FpTypography.numeric.fontFeatures, isNotEmpty);
    });
  });

  group('FpTheme', () {
    test('dark() is dark, uses Manrope and exposes FpTokens', () {
      final theme = FpTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, FpColors.background);
      expect(theme.textTheme.bodyLarge!.fontFamily, FpTypography.uiFamily);
      expect(theme.extension<FpTokens>(), isNotNull);
      expect(theme.extension<FpTokens>()!.colors.accent, FpColors.accent);
      expect(theme.colorScheme.primary, FpColors.accent);
    });

    test('FpTokens.copyWith and lerp', () {
      const a = FpTokens.dark;
      final b = a.copyWith(
        colors: const FpColorScheme(accent: Color(0xFF000000)),
      );
      expect(b.colors.accent, const Color(0xFF000000));
      expect(b.text, a.text);
      final mid = a.lerp(b, 0.5);
      expect(mid.colors.accent, isNot(a.colors.accent));
      expect(mid.colors.accent, isNot(b.colors.accent));
      expect(a.lerp(null, 0.5), a);
      expect(a.lerp(b, 0).metrics.spaceLg, 16);
      expect(a.lerp(b, 1).motion.fast, FpMotion.fast);
    });

    test('FpColorScheme.all and FpTextTheme.all list every slot', () {
      expect(const FpColorScheme().all.length, 23);
      expect(const FpTextTheme().all.length, 12);
      expect(
        const FpTextTheme().lerp(const FpTextTheme(), 0.3).body.fontSize,
        16,
      );
    });

    testWidgets('context.fp returns the theme tokens or the dark default', (
      tester,
    ) async {
      late FpTokens inTheme;
      late FpTokens noTheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: FpTheme.dark(
            tokens: const FpTokens(
              colors: FpColorScheme(accent: Color(0xFF123456)),
            ),
          ),
          home: Builder(
            builder: (context) {
              inTheme = context.fp;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(inTheme.colors.accent, const Color(0xFF123456));
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            noTheme = context.fp;
            return const SizedBox();
          },
        ),
      );
      expect(noTheme.colors.accent, FpColors.accent);
    });
  });
}
