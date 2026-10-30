@Tags(['golden'])
library;

import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] on the dark background at [textScale] and compares it with
/// `goldens/<name>_<scale>.png`. Animations are settled with explicit pumps
/// (never `pumpAndSettle`, which some components keep alive).
Future<void> _golden(
  WidgetTester tester,
  String name,
  Widget child, {
  required double textScale,
  Size size = const Size(400, 300),
  Duration settle = const Duration(seconds: 2),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: FpTheme.dark(),
      debugShowCheckedModeBanner: false,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(FpSpacing.lg),
          child: RepaintBoundary(
            key: const ValueKey('golden-root'),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump(settle);
  await tester.pump();
  final scale = textScale.toStringAsFixed(1).replaceAll('.', '_');
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/${name}_$scale.png'),
  );
}

void main() {
  for (final scale in [1.0, 1.3]) {
    group('goldens at ${scale}x', () {
      testWidgets('buttons', (tester) async {
        await _golden(
          tester,
          'buttons',
          Column(
            spacing: FpSpacing.md,
            children: [
              for (final v in FpButtonVariant.values)
                FpButton(label: v.name, variant: v, onPressed: () {}),
              FpButton(
                label: 'icon',
                leadingIcon: Icons.bolt,
                onPressed: () {},
              ),
              FpButton(label: 'loading', isLoading: true, onPressed: () {}),
              FpButton(label: 'disabled', enabled: false, onPressed: () {}),
              Row(
                spacing: FpSpacing.sm,
                children: [
                  for (final s in FpButtonSize.values)
                    Expanded(
                      child: FpButton(label: s.name, size: s, onPressed: () {}),
                    ),
                ],
              ),
            ],
          ),
          textScale: scale,
          size: const Size(400, 620),
          settle: const Duration(milliseconds: 100),
        );
      });

      testWidgets('surfaces and chips', (tester) async {
        await _golden(
          tester,
          'surfaces_chips',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: FpSpacing.lg,
            children: [
              for (final v in FpSurfaceVariant.values)
                FpSurface(
                  variant: v,
                  onTap: v == FpSurfaceVariant.raised ? () {} : null,
                  child: Text('${v.name} surface', style: FpTypography.body),
                ),
              Wrap(
                spacing: FpSpacing.sm,
                runSpacing: FpSpacing.sm,
                children: [
                  FpChip(label: 'Selected', selected: true, onSelected: (_) {}),
                  FpChip(label: 'Idle', onSelected: (_) {}),
                  FpChip(
                    label: 'Icon',
                    leadingIcon: Icons.flash_on,
                    onSelected: (_) {},
                  ),
                  const FpChip(label: 'Disabled', enabled: false),
                ],
              ),
            ],
          ),
          textScale: scale,
          size: const Size(400, 420),
        );
      });

      testWidgets('text fields', (tester) async {
        await _golden(
          tester,
          'text_fields',
          Column(
            spacing: FpSpacing.lg,
            children: [
              FpTextField(
                label: 'Name',
                controller: TextEditingController(text: 'Aarav Mehta'),
                helperText: 'As on your bank account',
              ),
              const FpTextField(
                label: 'Password',
                hint: 'Password',
                obscureText: true,
                prefix: Icon(Icons.lock_outline),
              ),
              const FpTextField(
                label: 'UPI ID',
                hint: 'name@bank',
                errorText: 'That UPI ID does not exist',
              ),
              const FpTextField(label: 'Disabled', hint: 'Off', enabled: false),
            ],
          ),
          textScale: scale,
          size: const Size(400, 520),
        );
      });

      testWidgets('toggles, segments, indicator', (tester) async {
        await _golden(
          tester,
          'controls',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: FpSpacing.lg,
            children: [
              Row(
                spacing: FpSpacing.lg,
                children: [
                  FpToggle(value: true, onChanged: (_) {}),
                  FpToggle(value: false, onChanged: (_) {}),
                  const FpToggle(value: true),
                ],
              ),
              FpSegmentedControl(
                segments: const ['Week', 'Month', 'Year'],
                selectedIndex: 1,
                onChanged: (_) {},
              ),
              const FpPageIndicator(count: 4, index: 1),
            ],
          ),
          textScale: scale,
          size: const Size(400, 240),
        );
      });

      testWidgets('otp field, countdown ring, drawn check', (tester) async {
        await _golden(
          tester,
          'otp_countdown_check',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: FpSpacing.lg,
            children: [
              FpOtpField(value: '24', onChanged: (_) {}),
              FpOtpField(value: '123456', error: true, onChanged: (_) {}),
              FpOtpField(value: '1234', enabled: false, onChanged: (_) {}),
              const Row(
                spacing: FpSpacing.lg,
                children: [
                  FpCountdownRing(progress: 1, label: '30'),
                  FpCountdownRing(progress: 0.4, label: '12'),
                  FpCountdownRing(progress: 0, label: '0', size: 40),
                  FpDrawnCheck(size: 64),
                  FpDrawnCheck(shown: false, size: 64),
                ],
              ),
            ],
          ),
          textScale: scale,
          size: const Size(400, 420),
        );
      });

      testWidgets('amount text', (tester) async {
        await _golden(
          tester,
          'amount_text',
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: FpSpacing.md,
            children: [
              FpAmountText(paise: 12345678),
              FpAmountText(
                paise: 99999999999,
                style: FpTypography.displaySmall,
              ),
              FpAmountText(paise: -4500, style: FpTypography.numeric),
              FpAmountText(paise: 12345678, hide: FpAmountHide.mask),
            ],
          ),
          textScale: scale,
        );
      });

      testWidgets('skeleton, empty and error states', (tester) async {
        await _golden(
          tester,
          'states',
          Column(
            children: [
              const FpSkeletonRow(),
              FpEmptyState(
                title: 'No transactions yet',
                message: 'Send money to see it here.',
                actionLabel: 'Send money',
                onAction: () {},
              ),
              FpErrorState(
                title: 'Could not load',
                message: 'Check your connection.',
                onRetry: () {},
              ),
            ],
          ),
          textScale: scale,
          size: const Size(400, 780),
        );
      });

      testWidgets('typography and colours', (tester) async {
        await _golden(
          tester,
          'tokens',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in FpTypography.all.entries)
                Text('${e.key} ₹1,23,456', style: e.value, maxLines: 1),
              const SizedBox(height: FpSpacing.lg),
              Wrap(
                spacing: FpSpacing.xs,
                runSpacing: FpSpacing.xs,
                children: [
                  for (final c in const FpColorScheme().all.values)
                    Container(width: 28, height: 28, color: c),
                ],
              ),
            ],
          ),
          textScale: scale,
          size: const Size(400, 640),
        );
      });

      testWidgets('gallery', (tester) async {
        await tester.binding.setSurfaceSize(const Size(430, 5600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: FpTheme.dark(),
            debugShowCheckedModeBanner: false,
            builder: (context, app) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: app!,
            ),
            home: const FpGalleryScreen(),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        final name = scale.toStringAsFixed(1).replaceAll('.', '_');
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/gallery_$name.png'),
        );
      });
    });
  }
}
