import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(SecureScreen.debugReset);

  testWidgets('enables on first mount, disables when the last one leaves', (
    tester,
  ) async {
    final protector = FakeScreenProtector();
    Widget build(int count) => Column(
      children: [
        for (var i = 0; i < count; i++)
          SecureScreen(protector: protector, child: const SizedBox()),
      ],
    );
    await tester.pumpWidget(build(1));
    expect(protector.enabled, isTrue);
    expect(protector.enableCalls, 1);
    await tester.pumpWidget(build(2));
    expect(protector.enableCalls, 1);
    expect(SecureScreen.activeCount, 2);
    await tester.pumpWidget(build(1));
    expect(protector.enabled, isTrue);
    expect(protector.disableCalls, 0);
    await tester.pumpWidget(build(0));
    expect(protector.enabled, isFalse);
    expect(protector.disableCalls, 1);
    expect(SecureScreen.activeCount, 0);
  });

  testWidgets('without a registered protector it is a no-op', (tester) async {
    await tester.pumpWidget(const SecureScreen(child: SizedBox()));
    await tester.pumpWidget(const SizedBox());
    expect(SecureScreen.activeCount, 0);
  });
}
