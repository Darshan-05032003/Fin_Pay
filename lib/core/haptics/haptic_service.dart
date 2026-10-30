/// The kinds of haptic feedback the app can request.
enum HapticType { light, medium, heavy, selection, success, error }

/// Single entry point for haptic feedback.
///
/// Screens and design-system components never call `HapticFeedback` or
/// `Vibration` directly; they ask for a [HapticType] through this interface so
/// the platform plugin can be replaced in tests ([FakeHapticService]) and the
/// user can switch haptics off in settings.
abstract interface class HapticService {
  /// Subtle feedback for small interactions (toggle, chip).
  Future<void> light();

  /// Standard feedback for button presses.
  Future<void> medium();

  /// Strong feedback for important actions (pay, confirm).
  Future<void> heavy();

  /// Feedback for selection changes (tabs, keypad digits, slider ticks).
  Future<void> selection();

  /// Pattern for a successful outcome.
  Future<void> success();

  /// Pattern for an error outcome.
  Future<void> error();

  /// Dispatches [type] to the matching method.
  Future<void> play(HapticType type) => switch (type) {
    HapticType.light => light(),
    HapticType.medium => medium(),
    HapticType.heavy => heavy(),
    HapticType.selection => selection(),
    HapticType.success => success(),
    HapticType.error => error(),
  };
}

/// Records every requested haptic instead of vibrating. Used in tests.
class FakeHapticService implements HapticService {
  /// Every haptic requested so far, in order.
  final List<HapticType> calls = [];

  /// Removes all recorded calls.
  void reset() => calls.clear();

  Future<void> _record(HapticType type) async => calls.add(type);

  @override
  Future<void> light() => _record(HapticType.light);

  @override
  Future<void> medium() => _record(HapticType.medium);

  @override
  Future<void> heavy() => _record(HapticType.heavy);

  @override
  Future<void> selection() => _record(HapticType.selection);

  @override
  Future<void> success() => _record(HapticType.success);

  @override
  Future<void> error() => _record(HapticType.error);

  @override
  Future<void> play(HapticType type) => _record(type);
}
