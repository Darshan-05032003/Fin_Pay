import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside the FinPay dark theme with optional reduced motion
/// and text scale.
Future<void> pumpFp(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
  double textScale = 1,
  Size? surfaceSize,
  bool scaffold = true,
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: FpTheme.dark(),
      debugShowCheckedModeBanner: false,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: app!,
      ),
      home: scaffold ? Scaffold(body: Center(child: child)) : child,
    ),
  );
}

/// A fresh fake haptic service per test.
FakeHapticService fakeHaptics() => FakeHapticService();
