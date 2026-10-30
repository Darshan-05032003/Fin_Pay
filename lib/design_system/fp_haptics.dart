import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:get_it/get_it.dart';

/// Resolves the [HapticService] a component should use.
///
/// Components accept an optional `haptics` parameter (tests inject
/// `FakeHapticService`). When it is null, the GetIt registration is used if
/// there is one; otherwise haptics are silently skipped.
HapticService? resolveHaptics(HapticService? given) {
  if (given != null) return given;
  if (GetIt.I.isRegistered<HapticService>()) return GetIt.I<HapticService>();
  return null;
}

/// Fire-and-forget haptic through [resolveHaptics]. Never throws into the
/// UI: a failing vibration plugin must not break a press.
void playHaptic(HapticService? given, HapticType? type) {
  if (type == null) return;
  final service = resolveHaptics(given);
  if (service == null) return;
  unawaited(service.play(type).catchError((Object _) {}));
}
