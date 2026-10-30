import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Where the OTP entry is.
enum OtpPhase {
  /// Accepting digits.
  entering,

  /// A submit is in flight.
  verifying,

  /// The last code was wrong (digits cleared, shake + red flash).
  wrong,

  /// Too many wrong codes; nothing more is accepted.
  locked,

  /// The code matched.
  verified,
}

/// Immutable state of the six-digit code entry.
///
/// The expected code is **not** part of the state: it lives in the cubit, so
/// state logs and `toString` never contain it.
class OtpState extends Equatable {
  const OtpState({
    this.digits = '',
    this.attempts = 0,
    this.phase = OtpPhase.entering,
    this.resends = 0,
    this.resendRemaining = OtpState.resendCooldown,
  });

  /// Number of cells.
  static const int length = 6;

  /// Wrong codes allowed before [OtpPhase.locked].
  static const int maxAttempts = 5;

  /// Time before "resend" becomes available again.
  static const Duration resendCooldown = Duration(seconds: 30);

  /// Digits typed so far (ASCII, ≤ [length]).
  final String digits;

  /// Wrong codes so far.
  final int attempts;
  final OtpPhase phase;

  /// How many times the code was resent.
  final int resends;

  /// Time left on the resend cooldown.
  final Duration resendRemaining;

  bool get complete => digits.length == length;

  /// The cell that receives the next digit (the last cell when complete).
  int get activeIndex => math.min(digits.length, length - 1);

  int get remainingAttempts => math.max(0, maxAttempts - attempts);

  bool get canResend =>
      resendRemaining <= Duration.zero &&
      phase != OtpPhase.locked &&
      phase != OtpPhase.verified &&
      phase != OtpPhase.verifying;

  /// 1 at the start of the cooldown, 0 when resend is available.
  double get resendProgress => resendCooldown.inMicroseconds == 0
      ? 0
      : (resendRemaining.inMicroseconds / resendCooldown.inMicroseconds).clamp(
          0.0,
          1.0,
        );

  bool get acceptsInput =>
      phase == OtpPhase.entering || phase == OtpPhase.wrong;

  OtpState copyWith({
    String? digits,
    int? attempts,
    OtpPhase? phase,
    int? resends,
    Duration? resendRemaining,
  }) => OtpState(
    digits: digits ?? this.digits,
    attempts: attempts ?? this.attempts,
    phase: phase ?? this.phase,
    resends: resends ?? this.resends,
    resendRemaining: resendRemaining ?? this.resendRemaining,
  );

  @override
  List<Object?> get props => [
    digits,
    attempts,
    phase,
    resends,
    resendRemaining,
  ];
}

/// The pure OTP state machine: every transition is a function from state
/// to state, so auto-advance, paste, backspace, attempts and lockout are
/// unit-tested without a widget or a cubit.
abstract final class OtpMachine {
  static final RegExp _nonDigit = RegExp('[^0-9]');

  /// Keeps ASCII digits only, at most [OtpState.length] of them.
  static String sanitize(String raw) {
    final digits = raw.replaceAll(_nonDigit, '');
    return digits.length > OtpState.length
        ? digits.substring(0, OtpState.length)
        : digits;
  }

  /// The hidden text field hands over its whole text (typing, paste or
  /// autofill): the digits replace the current ones.
  static OtpState input(OtpState s, String raw) {
    if (!s.acceptsInput) return s;
    return s.copyWith(digits: sanitize(raw), phase: OtpPhase.entering);
  }

  /// Removes the last digit (moves the active cell back).
  static OtpState backspace(OtpState s) {
    if (!s.acceptsInput || s.digits.isEmpty) return s;
    return s.copyWith(
      digits: s.digits.substring(0, s.digits.length - 1),
      phase: OtpPhase.entering,
    );
  }

  /// Marks a submit as in flight (the UI morphs the button). No-op unless
  /// the code is complete and accepted.
  static OtpState beginVerify(OtpState s) {
    if (!s.acceptsInput || !s.complete) return s;
    return s.copyWith(phase: OtpPhase.verifying);
  }

  /// Compares the typed code with [expected]: verified, wrong (attempt
  /// counted, digits cleared) or locked after [OtpState.maxAttempts].
  static OtpState verify(OtpState s, String expected) {
    if (s.phase == OtpPhase.locked || s.phase == OtpPhase.verified) return s;
    if (!s.complete) return s.copyWith(phase: OtpPhase.entering);
    if (codesMatch(s.digits, expected)) {
      return s.copyWith(phase: OtpPhase.verified);
    }
    final attempts = s.attempts + 1;
    return s.copyWith(
      digits: '',
      attempts: attempts,
      phase: attempts >= OtpState.maxAttempts
          ? OtpPhase.locked
          : OtpPhase.wrong,
    );
  }

  /// Starts a fresh code: clears the digits and a wrong phase, restarts the
  /// cooldown. Attempts are kept so resending never resets the lockout.
  static OtpState resend(OtpState s) {
    if (s.phase == OtpPhase.locked ||
        s.phase == OtpPhase.verified ||
        s.phase == OtpPhase.verifying) {
      return s;
    }
    return s.copyWith(
      digits: '',
      phase: OtpPhase.entering,
      resends: s.resends + 1,
      resendRemaining: OtpState.resendCooldown,
    );
  }

  /// Constant-time comparison of two codes of equal length; false for
  /// different lengths or empty codes.
  static bool codesMatch(String a, String b) {
    if (a.isEmpty || a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
