import 'dart:async';

/// Double-submit guard.
///
/// [run] invokes its action at most once per "submission window": while the
/// returned future is pending (or, for synchronous actions, for
/// [syncLockout]) every further call is dropped. 1,000 rapid taps on a pay
/// button therefore produce exactly one call.
class FpSubmitGuard {
  FpSubmitGuard({this.syncLockout = const Duration(milliseconds: 300)});

  /// How long a synchronous action keeps the guard locked.
  final Duration syncLockout;

  bool _locked = false;
  Timer? _timer;

  /// True while a submission is in flight.
  bool get isLocked => _locked;

  /// Runs [action] unless locked. Returns true when it ran.
  bool run(FutureOr<void> Function() action) {
    if (_locked) return false;
    _locked = true;
    final FutureOr<void> result;
    try {
      result = action();
    } catch (_) {
      _locked = false;
      rethrow;
    }
    if (result is Future<void>) {
      // Unlock when the future settles, and never before the sync lockout
      // elapses, so an instantly-completing future still debounces.
      final minimum = Future<void>.delayed(syncLockout);
      unawaited(
        Future.wait<void>([
          result.catchError((Object _) {}),
          minimum,
        ]).whenComplete(_unlock),
      );
    } else {
      _timer = Timer(syncLockout, _unlock);
    }
    return true;
  }

  void _unlock() {
    _locked = false;
    _timer = null;
  }

  /// Cancels any pending timer. Call from `dispose`.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
