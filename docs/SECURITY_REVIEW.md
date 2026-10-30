# Security review

One entry per feature, appended after the feature's quality loop (spec §7a).

## Feature: F2 Design system
- Attacks tried:
  - `FpTextField`: 10,000-character paste, mathematical-alphanumeric unicode,
    RTL override characters (U+202E/U+202C), 300× emoji, NUL / zero-width /
    BOM characters, `inputFormatters` bypass attempts, focus-node swapping
    (`fp_inputs_test.dart`).
  - `FpAmountText`: 0, ±1, the maximum ₹99,99,99,999.99, its negative,
    `int64` max and min, width changes between extremes, mask / blur modes
    (`fp_security_test.dart`, `fp_display_test.dart`).
  - `FpButton`: 1,000 rapid taps (widget + stress), two simultaneous pointers,
    taps while `isLoading`, taps while disabled, a callback whose future never
    completes, a callback whose future throws (`fp_button_test.dart`,
    `fp_motion_logic_test.dart`).
  - `FpBottomSheet`: pop mid-spring, double tap on the drag handle, two
    `show()` calls in the same frame, scrim tap with `isDismissible: false`,
    back navigation while open (`fp_overlays_test.dart`).
  - `FpToast`: host screen disposed while the toast is on screen, two toasts
    in a row, dismiss during the entrance.
  - Gallery: constructed with `isRelease: true` as if routed to in release.
  - Static scan of `lib/design_system` for `print` / `debugPrint` / `log` /
    `logger` calls and for `dart:developer` / `Clipboard` in the text field.
  - Semantics: `labeledTapTargetGuideline`, `androidTapTargetGuideline` and
    `textContrastGuideline` over the whole gallery (an unlabeled or
    low-contrast control is both an a11y and a phishing-surface defect).
- What broke:
  - **High** – first `FpSubmitGuard` draft unlocked as soon as an
    instantly-completing future resolved, so a `Future.value()` callback
    could be fired on every tap. Fixed before commit: a future-returning
    action is locked until *both* the future and the 300 ms window elapse.
  - **Medium** – `FpBottomSheet` kept a static "open" flag that stayed set
    if the route was removed without the `push` future completing (observed
    when a test aborted). A later `show()` would then be silently ignored
    app-wide. Fixed: the guard checks the live route's `isActive` instead.
  - **Medium** – a `FpPressable` with a label and semantic children produced
    a second, unlabelled tappable node (from `GestureDetector`), flagged by
    `labeledTapTargetGuideline`. Fixed with `excludeFromSemantics: true`
    and `container`/`explicitChildNodes` on the labelled node.
  - **Low** – Instrument Serif has no rupee glyph; big amounts rendered the
    symbol as tofu in tests (and would depend on an OS fallback on devices).
    Fixed with `fontFamilyFallback: ['Manrope']`.
  - **Low** – entrance delays used `Timer`s that could out-live a disposed
    widget. Replaced by a single controller with an `Interval` (D-011).
- Fixed now: all of the above, each with a regression test
  (`fp_motion_logic_test.dart` "async action", `fp_overlays_test.dart`
  "double show" / "popped mid-entrance", `gallery_test.dart` guidelines,
  `fp_security_test.dart`).
- Scope for improvement:
  - **Tapjacking on pay buttons (Agent A / F5):** `FpButton` is a Flutter
    widget and cannot set `filterTouchesWhenObscured`; it must be set on the
    Android `FlutterView` / activity window. Recommended: in
    `MainActivity`, `flutterView.filterTouchesWhenObscured = true` (or a
    platform channel toggled on the payment screens), plus
    `FLAG_SECURE` on balance / card / payment screens behind the screenshot
    protection interface. `FpButton` keeps the double-submit guard and the
    `medium` haptic so an obscured-tap attack still cannot repeat a
    submission.
  - `FpAmountHide.blur` reveals the digit count and magnitude through the
    blur; screens should use the default `mask` for balances in the app
    switcher. `blur` exists for the home "peek" interaction only.
  - `FpTextField` never logs, but the `TextEditingController` the screen
    passes in is the screen's responsibility: do not log `controller.text`
    and clear it on dispose for card numbers / CVV (F4).
  - Password fields set `enableSuggestions: false` and `autocorrect: false`;
    screens should also pass `autofillHints` so the OS keychain, not the
    keyboard's learning dictionary, handles credentials.
  - The gallery guard is build-mode based (`kReleaseMode`); Agent A must also
    leave the route out of the release router so it cannot be deep-linked.
