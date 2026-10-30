import 'package:fin_pay/core/platform/screen_protector.dart';

/// Records [enable]/[disable] calls instead of touching the window.
class FakeScreenProtector implements ScreenProtector {
  bool enabled = false;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async {
    enabled = true;
    enableCalls++;
  }

  @override
  Future<void> disable() async {
    enabled = false;
    disableCalls++;
  }
}
