import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fin_pay/screens/auth/verification/otp_machine.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the OTP entry: wraps [OtpMachine] and runs the resend countdown
/// against an injectable [Clock], so a clock jump can never leave the user
/// stuck (remaining time is clamped to the cooldown) and tests run on
/// `fake_async`.
///
/// The expected code is simulated locally (D-030): it is held privately and
/// never emitted in a state.
class OtpCubit extends Cubit<OtpState> {
  OtpCubit({
    required String expectedCode,
    Clock? clock,
    this.autoSubmit = false,
    this.tick = const Duration(seconds: 1),
  }) : _expected = expectedCode,
       _clock = clock ?? const Clock(),
       super(const OtpState()) {
    _startCooldown();
  }

  final String _expected;
  final Clock _clock;

  /// Submit as soon as the sixth digit arrives.
  final bool autoSubmit;

  /// Countdown resolution.
  final Duration tick;

  Timer? _timer;
  DateTime? _deadline;
  bool _submitting = false;

  /// True while the cooldown timer is running.
  bool get isCounting => _timer != null;

  /// Whole-text input from the hidden field (typing, paste, autofill).
  void input(String raw) {
    final next = OtpMachine.input(state, raw);
    if (next == state) return;
    emit(next);
    if (autoSubmit && next.complete) unawaited(submit());
  }

  void backspace() {
    final next = OtpMachine.backspace(state);
    if (next != state) emit(next);
  }

  /// Verifies the typed code. Concurrent calls verify once.
  Future<void> submit() async {
    if (_submitting) return;
    final begun = OtpMachine.beginVerify(state);
    if (begun == state) return;
    _submitting = true;
    emit(begun);
    // Let the "verifying" frame paint before the result lands.
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;
    emit(OtpMachine.verify(state, _expected));
    _submitting = false;
  }

  /// Requests a new code once the cooldown has elapsed.
  void resend() {
    if (!state.canResend) return;
    final next = OtpMachine.resend(state);
    if (next == state) return;
    emit(next);
    _startCooldown();
  }

  void _startCooldown() {
    _deadline = _clock.now().add(OtpState.resendCooldown);
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) => _tick());
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null) return;
    final raw = deadline.difference(_clock.now());
    // A clock jump backwards would inflate the remaining time; clamp it so
    // the user is never locked out of resend for longer than the cooldown.
    final remaining = raw < Duration.zero
        ? Duration.zero
        : raw > OtpState.resendCooldown
        ? OtpState.resendCooldown
        : raw;
    if (remaining == Duration.zero) {
      _timer?.cancel();
      _timer = null;
    }
    if (remaining != state.resendRemaining) {
      emit(state.copyWith(resendRemaining: remaining));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
