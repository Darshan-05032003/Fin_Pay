# Security review

One entry per feature, appended after the feature's quality loop (spec §7a).

## Feature: F1 Foundations
- Attacks tried:
  - `Money.parse` with 100,000-digit strings, 100,000 emoji, Devanagari/Arabic-Indic/fullwidth digits, NBSP and bidi marks, a U+202E right-to-left *override* (`‮001` renders as `100`), exponents (`1e5`), hex, two decimal points, trailing signs, `Infinity`/`NaN` (`test/unit/core/money/money_test.dart`).
  - int64 bounds: `Money.max + 1 paisa`, `-Money.min`, `Money.min.abs()`, `Money.max * 2`, `(1<<40) * (1<<40)`, parse of `92233720368547758.08`; a balance update that would overflow (`saveTransaction` on a `Money.max` balance).
  - Auth: wrong password ×5 and the right password while locked; the right password after the lock expires (fake `Clock`); e-mail variants (`  USER@FinPay.com `, bidi marks); unicode/emoji/RTL/5,000-char passwords; a 257-char password and a 250-char local part (rejected before PBKDF2); corrupt credential and lockout JSON in storage; secure storage throwing; a valid password with no user row; unknown e-mail vs wrong password (same failure type and attempt count, so user enumeration is not possible).
  - Rapid double submit: 20 concurrent `saveTransaction` calls with one `idempotencyKey`; 1,000 `AddTransactionEvent`s with each key submitted twice through the BLoC; two `SessionCubit.signIn` calls while one is in flight.
  - Process death mid-migration: an injected fault after the transactions step; reopen; v1 data intact at version 1, second open completes v2 (`app_database_test.dart`).
  - Clock/timezone: local dates (including a DST-gap time) stored and read back as UTC instants; the `createdAt` column from an injected `Clock`.
  - Secrets in source: `git grep -n -i -E "api_key|apikey|secret|AIza|password\s*=\s*'" lib/` and the plaintext demo password, as a unit test (`demo_credentials_test.dart`) so CI fails if either reappears.
  - Logger: card numbers with spaces/dashes, CVVs, `password=`/`pin:`/`otp:`/`token:` values in plain and JSON form; every level in forced release mode.
  - Route guard bypass: every route × {unknown, authenticating, unauthenticated, authenticated} × {debug, release} as a pure-function matrix, plus live `GoRouter` tests (`/home` while signed out, `/login` while signed in, sign-out from `/profile`, `/gallery` in release, untyped `extra` on `/transfer-review`).
  - Manifest review: `allowBackup`, exported components, intent filters, `targetSdk`.
- What broke:
  - **High** — plaintext password stored in SQLite (`users.password`) and compared with `==` against a hardcoded `'FinPay123'` in `lib/`.
  - **High** — full card PAN and CVV stored in plaintext SQLite (`cards.cardNumber`, `cards.cvv`) and included in `android:allowBackup` (default true) cloud backups.
  - **High** — no idempotency: a double tap on "pay" or a retried review wrote two transactions and debited the balance twice; the balance update was a separate read-modify-write after the insert.
  - **High** — no auth guard: `initialRoute: '/'` and `onGenerateRoute` let any route be opened regardless of auth state; `RouteGuard` existed but was never called.
  - **Medium** — `Logger.error` printed in release builds, and nothing redacted card numbers/CVVs/passwords; the create-account flow passed the plaintext password through route arguments.
  - **Medium** — no lockout, so the password could be brute-forced on-device at UI speed.
  - **Medium** — amounts as `double`: `0.1 + 0.2`, `1.005` and large balances lost paise; nothing checked for overflow.
  - **Medium** — `Money.parse`-style input was `double.tryParse`, which accepts `1e5`, `Infinity` and `NaN`.
  - **Low** — `targetSdk` pinned to 34 while `compileSdk` floats with Flutter; `RouteGuard`, `NetworkService` (with fake API URLs), `AppConfig` dead code.
  - **Low** — transaction dates stored as local ISO strings without an offset, so a timezone change shifted the day grouping.
- Fixed now:
  - Credentials are a salted PBKDF2-HMAC-SHA256 hash (10k iterations, 16-byte salt, constant-time compare) in `flutter_secure_storage` behind `SecureStorage`; the demo `(salt, hash)` is a precomputed constant, the plaintext lives only in README/tests; the `password` column is dropped by the v2 migration. Regression: `password_hasher_test.dart`, `auth_repository_test.dart`, `demo_credentials_test.dart`.
  - Lockout after 5 failures for 30 s, persisted per e-mail, clock-driven; `AuthenticateUserUseCase` caps input length. Regression: `auth_repository_test.dart` (lockout group).
  - Card PAN/CVV move to secure storage (`card:<id>`); the v2 `cards` table holds only the mask; `PaymentCard.toJson`/`toString` never include them. Regression: `sqflite_local_datasource_test.dart` ("stores only the masked number"), `card_repository_test.dart`, `models_test.dart`.
  - `android:allowBackup="false"` + `dataExtractionRules` (API 31+) + `fullBackupContent` excluding everything; `USE_BIOMETRIC` permission added for `local_auth`; the activity is the only exported component and has no deep-link filter; `targetSdk = flutter.compileSdkVersion`.
  - Idempotent, atomic transaction recording (unique `idempotencyKey`, insert + balance update in one exclusive transaction, `insufficientBalance`/`duplicate` outcomes). Regression: datasource tests (duplicate, 20 concurrent submits, overflow, insufficient), `transaction_bloc_test.dart` (burst of five), stress test (1,000 adds → 500 rows).
  - go_router redirect driven by `SessionCubit`, `/gallery` debug-only, typed `TransferDraft` extras (untyped → guard screen). Regression: `app_redirect_test.dart` (22 cases), `app_router_test.dart` (8 live cases).
  - `Logger` silent in release, `redact()` on every message and error (Luhn-checked PANs keep only last 4). Regression: `logger_test.dart`.
  - `Money` int paise with overflow checks and a strict parser. Regression: `money_test.dart` (44 cases).
  - Dates normalised to UTC in the models and stored as ISO-8601 `Z`; `localDate`/`localTime` for display. Regression: datasource "dates round-trip as UTC instants", stress "clock/timezone".
  - `FLAG_SECURE` is available through `ScreenProtector` (`fin_pay/screen_protector`, Kotlin in `MainActivity.kt`); screens owned by D/E switch it on for balance/card/payment screens.
  - Dead `RouteGuard`, `NetworkService`, `AppConfig` and the credential statics on `UserService` are deleted.
- Scope for improvement:
  - Data at rest: names, e-mail, balances, transaction titles/recipients and notifications are still plaintext in `finpay.db`. Backups are off and the file is app-private; SQLCipher (`sqflite_sqlcipher`) with a key in secure storage is the next step if the owner wants encryption at rest.
  - The create-account flow still passes the typed password through `GoRouter` `extra` (in-memory only, never persisted) to the verification screen; agent C should hash at the create-account step or collect the password after verification.
  - Lockout is per device; a wipe of secure storage resets it. A server would be needed for anything stronger.
  - `PaymentCard.cvv` is held in memory while a card is displayed; the card screens (D) must mask it by default and clear it when the screen is left.
  - Tapjacking (`filterTouchesWhenObscured`) and screenshot protection are hooks for F4/F5 screens, not applied to the legacy screens.
  - Release builds: run `flutter build apk --release --obfuscate --split-debug-info=build/symbols` (documented in README); R8 minify/shrink is already on in `build.gradle.kts`.
  - The demo password still appears in the README by design; the login screen only says "password in the README".

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

## Feature: F3 Onboarding + Auth
- Attacks tried:
  - Every field: 10,000-character pastes, 300× emoji, right-to-left overrides
    (U+202E), NUL / zero-width / BOM characters, Devanagari and Arabic-Indic
    digits, SQL (`' OR 1=1 --`), format strings (`%s%n`), `<script>`, a
    250-character local part, 65-code-point passwords
    (`validators_test.dart`, `login_cubit_test.dart` "hostile input",
    `login_screen_test.dart` "hostile input never throws").
  - OTP: 10,000 random inputs mixing junk and backspace/verify/resend
    through the pure machine; 2,000 junk pastes through the real
    `FpOtpField`; wrong code × 7; resend before and after the cooldown;
    concurrent submits; the expected code searched for in `state.toString()`
    and `props` (`otp_machine_test.dart`, `otp_cubit_test.dart`,
    `auth_stress_test.dart`).
  - Rapid taps: 50 (widget) and 1,000 (stress) taps on "Sign in" with the
    repository gated on a `Completer`; 1,000 `submit()` calls while one is in
    flight; 20 taps on the fingerprint glyph; three concurrent
    `completeSignUp()` calls; three concurrent `OtpCubit.submit()` calls.
  - Backgrounding mid-login: `AppLifecycleState` inactive → hidden → paused
    while the password is revealed, on login and create account.
  - Process death mid-OTP / deep link: `/verification` opened with no pending
    sign-up (router test and screen test); `/fingerprint-setup` opened while
    signed out and "not now" pressed; `/home` while signed out.
  - Biometrics: `failed`, `lockedOut`, `error`, `notEnrolled`, `notAvailable`
    at check time and at prompt time; retry after failure.
  - Clock jumps: +2 h and −5 h during the OTP cooldown; −1 h during the login
    lockout (`fake_async` + injected `Clock`).
  - Route `extra` inspected after the sign-up push (`router.state.extra`).
  - Password visibility: eye toggle, re-hide on background; password and OTP
    searched for in every emitted state; `demo_credentials_test.dart` greps
    `lib/` for the owner's secret regex (it caught the first draft's private
    `_password = ''` field, renamed).
  - FLAG_SECURE: `FakeScreenProtector` call counts across login → create
    account → back → welcome.
  - Enumeration: forgot-password with an unknown vs a known address.
  - Semantics guidelines (`androidTapTargetGuideline`,
    `labeledTapTargetGuideline`, `textContrastGuideline`) on every screen at
    1.3× with errors showing.
- What broke:
  - **Medium** (carried from F1) – the plaintext password travelled through
    `GoRouter` `extra` from create account to verification. Fixed: shell-scoped
    `CreateAccountCubit` (D-032); the password is a private field, never in a
    state, wiped on close; `router.state.extra` is asserted null after the
    push (`create_account_screen_test.dart`, `app_router_test.dart`).
  - **Medium** – the old verification screen accepted *any* four digits and
    "resend" did nothing. Fixed: six-digit code compared in constant time,
    five attempts then lockout, resend only after a 30 s cooldown and never
    resetting attempts (`otp_machine_test.dart`).
  - **Medium** – no screenshot protection on the credential screens. Fixed:
    `SecureScreen` (reference-counted `FLAG_SECURE`) on login, create account
    and verification (`secure_screen_test.dart`, `login_screen_test.dart`
    "screen protection stays on").
  - **Low** – a revealed password stayed visible in the app switcher after
    backgrounding. Fixed: re-obscured on `inactive`/`hidden`/`paused`.
  - **Low** – the first `LoginCubit` draft clamped the lock countdown to 5
    minutes, so a clock jump backwards could extend a 30 s lock. Fixed: clamp
    to the originally granted length (`login_cubit_test.dart` "clock jump").
  - **Low** – `Validators.validateEmail` accepted any `\w`-ish local part and
    `validateName` accepted symbols. Fixed: ASCII-only, length-bounded email;
    letter/mark-only names; control and bidi characters rejected everywhere.
  - **Low** – demo credentials were printed on the login and sign-up screens.
    Fixed: the screens only say the details are in the README (asserted by
    `login_screen_test.dart`).
  - Nothing Critical/High found: the repository lockout (F1) already stops
    brute force; 1,000 rapid taps and 1,000 in-flight submits reach the
    repository once; the OTP flow cannot be reached without a pending sign-up.
- Fixed now: all of the above, each with a regression test (listed per item).
- Scope for improvement:
  - The simulated OTP is derived from the phone number (D-030); a real
    deployment needs a server-issued code with its own rate limit.
  - `biometricEnabled` is persisted but biometric sign-in is not wired (see
    DECISIONS F3 compromises); when it is, keep the hash check and gate a
    keystore-held secret behind `BiometricAuthenticator`.
  - `AutofillGroup`/`autofillHints` are set; iOS/Android keychain behaviour
    needs a device check in Wave 2.
  - Tapjacking (`filterTouchesWhenObscured`) remains a `MainActivity` change
    (F2 note) and is not applied to the auth screens.
  - The forgot-password "sent" state is simulated; a real sender must keep
    the same constant-time, non-enumerating response.

## Feature: F4 Home + Cards
- Attacks tried:
  - PAN/CVV in logs: a static scan of `lib/screens/home`, `lib/screens/cards`, `lib/screens/shell` and the new design-system files for `print`/`debugPrint`/`Logger` (none); `Logger.redact` asserted on `cvv: 987` and JSON form (`cvv_reveal_cubit_test.dart`); every `AddCardCubit` and `CvvRevealCubit` state searched for the typed CVV in `toString()` and `props` (`add_card_cubit_test.dart`, `cvv_reveal_cubit_test.dart`); `CardContent.toString()` searched for the PAN and CVV with `maskSensitive` (`card_bloc_test.dart`).
  - Clipboard: `SystemChannels.platform` mocked; "Copy last 4" captured → `1111` only; no other clipboard call exists (`card_details_screen_test.dart`).
  - Screenshots: `FakeScreenProtector` asserted enabled on home, cards, add card and details, and disabled on statistics/profile; counted across tab switches and pushes (`app_shell_test.dart`, screen tests).
  - CVV lifetime: reveal → 5 s countdown → masked; `hide()`; close; a reveal that completes after `hide()` is discarded; 100 concurrent reveals read storage once; clock jumps forward/backward (`cvv_reveal_cubit_test.dart`, `my_cards_screen_test.dart`).
  - Backgrounding: `inactive` → the CVV is masked and the card turned over on the stack and in details; the add-card preview flips to its front; checked again after `paused` → `resumed` (`my_cards_screen_test.dart`, `add_card_screen_test.dart`).
  - Hostile input in add card: `\u202E` × 5,000, 😀 × 5,000, Devanagari / Arabic-Indic / fullwidth digits, NUL, `<script>`, `%s%n`, `' OR 1=1 --`, a 100,000-character paste, a 10,000-digit paste (`card_validators_test.dart` 24 groups / 90+ cases, `add_card_cubit_test.dart`, `add_card_screen_test.dart`).
  - Double submit: 50 taps on "Add card" with a gated repository (widget), 1,000 `submit()` calls (unit) and 1,000 taps (stress) → one `addCard`; 100 concurrent `remove()` → one `deleteCard`; a finished form cannot submit again.
  - Duplicate card: same last 4 + expiry refused before any write.
  - Sensor: `FakeMotionSensor(available: false)` → drag fallback, no subscription; reduce motion → no subscription; a 50 g sample is clamped; listeners counted at 0 after leaving the tab and after dispose (`my_cards_screen_test.dart`, stress).
  - Route bypass: `/cards/add`, `/cards/c1`, `/cards/a%20b` while signed out, authenticating and with an unknown session (pure matrix + live router); `/cards/nope` with a session shows "Card not found" and never touches storage (`app_redirect_test.dart`, `app_shell_test.dart`, `card_details_screen_test.dart`).
  - Rapid taps on hide-balance: 1,000 → final state consistent, exactly 1,000 writes (stress).
  - Secrets scan: `demo_credentials_test.dart` greps `lib/` (it caught a `maskSecrets` identifier in the first draft; renamed).
  - Semantics guidelines (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) on home (expanded and collapsed), cards (pile, fanned, flipped), add card (with errors, back shown) and details at 1.3×.
- What broke:
  - **Medium** (carried from F1, listed there as scope) – the app-wide `CardBloc` kept every card's PAN and CVV in memory for the app's lifetime and `CardContent.toString()` printed them. Fixed: `CardBloc(maskSensitive: true)` strips both on load and in the `CardAdded` effect; the CVV is read on demand through `ICardRepository.readCvv` (D-041). Regression: `card_bloc_test.dart` "maskSensitive".
  - **Medium** (UI audit 2.9) – the legacy card back printed the CVV in plain text, permanently. Fixed: masked by default, 5 s timed reveal from the keystore, re-masked on backgrounding (D-042). Regression: `cvv_reveal_cubit_test.dart`, `my_cards_screen_test.dart`.
  - **Medium** (UI audit 2.10) – the legacy add-card form had no formatting, no Luhn/expiry/CVV checks, no `autofillHints` and the keyboard could learn the number. Fixed: formatters, validators, `enableSuggestions: false` / `autocorrect: false` on number and CVV, no autofill on the CVV, obscured CVV field, controllers cleared on dispose. Regression: `card_validators_test.dart`, `add_card_screen_test.dart` "content".
  - **Low** – the first `FpRefreshIndicator` draft rethrew an `onRefresh` failure as an uncaught async error (a failed reload could take the screen down). Fixed: reported through `FlutterError.reportError`, glyph retracts. Regression: `fp_refresh_indicator_test.dart` "a throwing refresh".
  - **Low** – the first draft kept a perspective matrix on flip/tilt cards at rest, which shifted the semantics rects and made the contrast guideline sample the wrong pixels (a screen reader would also get a skewed bounds box). Fixed: identity at rest (D-046).
  - **Low** – the first `AddCardCubit` draft treated a *closed* `CardBloc` as a hang (`effects.first` threw `StateError` instead of timing out). Fixed: a closed or silent bloc is a failure the user can retry. Regression: "a bloc that never answers".
  - Nothing Critical: the keystore path from F1 holds (PAN/CVV written once, read for the reveal, deleted with the card), the session guard covers the new routes, and no secret reaches a state, a log or the clipboard.
- Fixed now: all of the above, each with the regression test named. Added: `filterTouchesWhenObscured` on the window's decor view in `MainActivity.onResume` (tapjacking on reveal-CVV / remove-card / the F5 pay button); not compiled on this machine (no Gradle), to be confirmed by the first device build.
- Scope for improvement:
  - The ledger has no card column, so card details lists all `payment` rows (D-047); a real card filter needs a schema change.
  - Freeze is session-local (D-047).
  - `TransactionBloc` loads the full ledger for home; F6 should page so a 100k-row ledger does not sit in memory behind five rows.
  - The recents thumbnail is blank on home/cards (FLAG_SECURE) but statistics/profile are unprotected until Agent F decides; the hide-balance setting is respected wherever these screens render amounts, so a protected-less tab showing the balance would need the same mask.
  - Dart strings cannot be zeroed (D-041); if the owner wants a stronger guarantee the CVV should stay native (platform channel returning a short-lived token) and never cross into Dart.
  - `CvvRevealCubit` reads from secure storage on every reveal; on a device the keystore round trip is tens of milliseconds, acceptable, but it should not be made cheaper by caching.

## Feature: F5 Payments
- Attacks tried:
  - Amount tampering via the route extra: `/transfer-review` pushed with a draft whose amount is zero, negative, int64 min/max, or ₹1,00,000.01, and with a blank key, name or VPA (`payment_cubit_test.dart` "tampered drafts", 8 cases; `transfer_review_screen_test.dart` "a tampered extra"). A bare `TransferDraft` and a `Map` pushed to `/transfer-review` and `/transfer-success` (`app_router_test.dart`, `transfer_success_screen_test.dart`).
  - Replay with the same key: the same draft paid twice through two cubits, a settlement timeout followed by Retry, 1,000 sequential payments of which 100 time out and retry (`payment_cubit_test.dart` "idempotency", stress scenario 2).
  - Double submit: 1,000 concurrent `pay()` calls, 50 and 1,002 rapid swipes/taps plus a two-finger drag on the slider with the bank gated, two taps on the reduce-motion button, the semantics tap action (`fp_swipe_to_pay_test.dart`, review widget tests, stress scenario 1).
  - Back and backgrounding mid-payment: back arrow, system back (`handlePopRoute`), `paused` → `resumed`, a slow ledger with a "process restore" (new review for the same draft) (`transfer_review_screen_test.dart` "mid-payment").
  - Hostile input: fullwidth / Arabic-Indic / Devanagari digits, `\u202E` bidi override, `1e5`, `<script>`, `' OR 1=1 --`, emoji, a 100,000-character paste and a 100,000-zero-width paste on the amount; control characters, bidi marks, zero-width joiners and a 100,000-emoji note; a hostile search query (`amount_input_test.dart`, `contact_search_test.dart`, `transfer_screen_test.dart`).
  - Clipboard: the only reads/writes go through a mocked platform channel; the copied receipt was asserted to contain the masked VPA and never the full VPA or the idempotency key (`transfer_success_screen_test.dart`); the amount paste is truncated to 64 characters before parsing.
  - Log hygiene: a static scan of every payment file for `print`/`debugPrint`/`Logger`/`developer.log` (`log_hygiene_test.dart`); `toString()` of every state, request, receipt and contact asserted free of amounts and VPAs.
  - Screenshots: `FakeScreenProtector` asserted enabled on review (idle, processing and failure) and success, and disabled on the amount screen.
  - Semantics guidelines (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) at 1.3× on transfer (with an error), review (idle and failure) and success; the slider's screen-reader path exercised.
  - A ledger that never answers (fake clock, 10 s timeout), a closed `TransactionBloc`, a throwing gateway, a declining settlement.
- What broke:
  - **Medium** (legacy, UI audit) – the legacy review compared the amount against a `UserService` balance read at tap time and wrote `amount: -transferAmount`: a negative draft in the route extra would have *credited* the account, and nothing bounded the amount. Fixed: `PaymentCubit` refuses non-positive, over-maximum and blank drafts before the bank or the ledger is called, and the ledger's exclusive transaction is the balance authority (D-052). Regression: "tampered drafts" (8 cases), "a tampered extra".
  - **Medium** (legacy) – `/transfer-success` rendered any `TransferDraft`, so a crafted extra produced a "Payment sent" page for a payment that never happened. Fixed: the route accepts only a `PaymentReceipt` minted by the cubit (D-051). Regression: `app_router_test.dart`, `transfer_success_screen_test.dart` "without a receipt".
  - **Medium** (F1 blocs, found by the harness) – `NotificationBloc`/`TransactionBloc` added to their effects controller after `close()` when storage answered late (`Bad state: Cannot add new events after calling close` as an uncaught async error). Fixed: `_emitEffect` guard (D-059). Regression: the review widget suite runs the real notification write on every success.
  - **Low** – the first transfer-screen draft switched the inline error through a keyed `AnimatedSwitcher`; flipping error → none → error inside its 150 ms produced duplicate keys and an exception (found by the 10,000-key stress). Fixed: one `Text` under `AnimatedDefaultTextStyle`.
  - **Low** – the first `PaymentCubit` draft awaited the broadcast subscription's `cancel()` future, which is the root-zone null future: inside `fake_async` the continuation never ran and a ledger timeout could not be reported. Fixed: synchronous cancel. Regression: "a ledger that never answers".
  - Nothing Critical: the idempotency key is minted once per confirmation, the ledger refuses duplicates in one exclusive transaction, the slider and the cubit each drop concurrent confirms, and no secret, amount or address reaches a log or the clipboard unmasked.
- Fixed now: all of the above, each with the regression test named. Payment screens (review, processing, failure, success) are under `SecureScreen`.
- Scope for improvement:
  - "Insufficient balance" is reachable only through a stale balance or a crafted extra (D-050); a real backend would also return it for concurrent spends.
  - The demo gateway's "flaky" memory is per process (D-057); a real gateway keeps idempotency server-side.
  - The receipt is copied as text; a system share sheet (`share_plus`) would use the same `shareText()`.
  - The note is not persisted (D-058); when a column is added it must be sanitised again on read.
  - `filterTouchesWhenObscured` (F4) covers the slider on Android; it is still unverified on a device build.

## Feature: F6 Insights + Activity
- Attacks tried:
  - Search injection and hostile strings through `searchTransactions`: `' OR 1=1 --`, `'; DROP TABLE transactions; --`, NUL, `\u202E` bidi override, Arabic, 1,000 emoji, 100,000 `x`, `%`, `_` and `\` (LIKE metacharacters) against the real ffi database with 120 rows (`sqflite_local_datasource_test.dart` "search is parameterised"), through the cubit (`transactions_cubit_test.dart` "hostile strings") and through the real screen (`transactions_screen_test.dart` "hostile search strings"); the row count is asserted unchanged afterwards.
  - Negative, zero and huge `limit`/`offset` on `getTransactions` and `searchTransactions` (`limit: -1`, `0`, `offset: -50`, `1 << 40`).
  - Deleted-row undo replay: undo tapped twice, undo after the toast expired, undo after the filter changed, delete of an unknown or already pending id, 1,000 dismiss + undo cycles on the notifications screen with the repository mocks counting writes (cubit, bloc, widget and stress tests).
  - Settings tampering: a failing settings save (`InMemorySettingsRepository.failing`) during a toggle; persisted values reflected on open; the F1 `SharedPreferencesSettingsRepository.load` fallback to defaults on a corrupt store (existing tests).
  - Logout: confirm → `SessionCubit.signOut` once (three rapid confirms, a throwing repository, a closed cubit), then `/profile` and `/transactions` requested directly while signed out (`profile_screen_test.dart` "protected routes stay closed").
  - `FakeScreenProtector` asserted enabled on `/transactions` and on the Stats tab (totals), disabled on Profile.
  - Log hygiene: a static scan of the four screen folders and `fp_swipe_action_row.dart` for `print`/`debugPrint`/`Logger`/`developer.log`/`Clipboard` (`insights_log_hygiene_test.dart`); `toString()` of `TransactionsState`, `StatsState` and `StatsSummary` asserted free of amounts, titles and queries.
  - Hide-balance respected in the transactions rows and detail sheet, the statistics totals, tooltips, chart descriptions and merchants; the counterparty in the detail sheet is masked (`P••••••••••••n`).
  - Int64 bounds: a spend of `Money.max − 1` plus another row through `StatsMath` (throws `MoneyOverflowException`) and through `StatsCubit` (error state, no crash).
  - Semantics guidelines (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`) at 1.3× on all four screens; custom semantics actions on the swipe row performed without a gesture.
- What broke:
  - **Medium** – a 100,000-character search reached SQLite as a `LIKE` pattern and failed with "pattern too complex" (SQLite's 50,000-byte limit), so a pasted blob turned the screen into a storage error. Fixed: the data source bounds the query to 200 characters before building the pattern and the cubit bounds it too (D-068). Regression: "search is parameterised" (100,000-character prefix still matches as data), cubit "bounded to 200 characters".
  - **Medium** (legacy) – the old transactions and notifications screens persisted deletions with `UserService.saveTransactions/saveNotifications`, which deleted *every stored row not in the screen's in-memory list*; a stale or partially loaded list would have wiped rows. Gone with `UserService`: deletes are per id through the cubit/bloc (D-063, D-064).
  - **Low** – a negative `limit` was handed to SQLite, which reads `LIMIT -1` as "unlimited" (a caller bug would dump the whole ledger); a negative `offset` was silently zero. Fixed: both normalised to zero rows / no skip, `limit: 0` returns nothing (D-068). Regression: "negative limit or offset never means everything".
  - **Low** – `NotificationBloc._onAdd` prepended unconditionally, so an undo replayed twice (two toasts, a double tap) duplicated the row in the state while storage kept one. Fixed: de-duplicate by id and insert in storage order. Regression: "add keeps newest-first order and never duplicates an id".
  - **Low** – the Stats tab was not under `FLAG_SECURE` (the F4 shell protected Home and Cards only) although it shows period totals. Fixed: `AppShell.protectedTabs` includes it; the shell test asserts it.
  - Nothing Critical or High: every query is parameterised (`whereArgs`), the undo paths are idempotent at the storage level (`idempotencyKey` unique index; notification `REPLACE` by id), logout clears the session through the one repository and the redirect is driven by the session stream, and no amount, title, counterparty or query reaches a log or `toString`.
- Fixed now: all of the above, each with the regression test named.
- Scope for improvement:
  - Keyset paging for ledgers past ~400k rows (D-061); `OFFSET 99,950` costs 30 ms today.
  - A biometric-availability check before offering the "Biometric sign-in" toggle (today it stores the preference only, as in F3).
  - SQLCipher for data at rest (F1 open item) would also cover the notification texts.
  - Only one swipe row open at a time (D-065) would stop two open trays from stacking "Delete" buttons on screen.

## Feature: F7 App-wide polish + Wave 2
- Attacks tried:
  - Generated Android resources after `flutter_launcher_icons` and `flutter_native_splash:create`: diffed `AndroidManifest.xml` (unchanged: `allowBackup="false"`, `fullBackupContent`/`dataExtractionRules` kept, `MainActivity` the only exported component, no VIEW/deep-link filter, no `usesCleartextTraffic`), every `styles.xml` variant (only window themes and splash items; no `android:debuggable`, no network config), the new `mipmap-anydpi-v26`, `drawable-*` and `values-v31` files (bitmaps, colours and the Android 12 splash items only). `MainActivity.kt` (FLAG_SECURE channel, `filterTouchesWhenObscured`) is untouched.
  - iOS: `Info.plist` gained only `UIStatusBarHidden=false`; no ATS exception, no URL schemes.
  - Dependency surface: `flutter_svg`, `url_launcher` and `cupertino_icons` removed (zero imports; `url_launcher` was the only package able to open external URLs). `flutter_native_splash` runs two platform calls at start-up and nothing after `remove()`; `flutter_launcher_icons`, `integration_test` and `flutter_driver` are dev/test only and never ship.
  - Integration tests: `git grep` for the demo password finds it only in `integration_test/flows.dart` and the README; both are public by design (spec §10, D-030). The tests use `enterText` through the keys the screens already had, read nothing from secure storage and print no credential; the perf driver writes timeline JSON only (frame timings, no app data).
  - Theme swap: with `FpTheme.dark()` at the root, `MaterialApp.themeMode` is forced dark, so a system light theme cannot surface light Material defaults around sensitive content; `FLAG_SECURE` behaviour is unchanged (shell tabs and credential screens).
  - Route guard regression after the transition map change: the redirect is untouched; `app_router_test.dart` still asserts protected routes redirect when signed out, guest routes redirect when signed in, the gallery is unreachable in release and the transfer review/success routes reject untyped extras; the token scan asserts no screen, route or app file imports the deleted legacy theme.
- What broke:
  - **Medium** – the shipped app ran under the legacy `AppTheme` (font "Inter", a different background, no `FpTokens` extension) although every test ran under `FpTheme.dark()`; Material-owned surfaces (snackbars, app bars, dialogs) were off-palette on the device and the native splash would have handed over to a different background. Fixed (D-072), pinned by `test/widget/app_test.dart`.
  - **Low** – the Android `NormalTheme` window background resolved to white under a `Theme.Light` parent, so a light frame could show behind the Flutter view at start-up and during keyboard resizes (not a data leak, a flash). Fixed (D-071).
  - **Low** – `/gallery` rendered a placeholder in the app: the profile "Widget gallery" row led nowhere in debug. Fixed (D-076); release behaviour unchanged.
  - Nothing Critical or High. The icon and splash add no attack surface: static bitmaps and colours, no code, no permissions, no exported components.
- Fixed now: all of the above.
- Scope for improvement:
  - SQLCipher for data at rest and a keystore-backed biometric sign-in remain open from F1/F3.
  - Run the integration flows on a device with `adb shell dumpsys window` to confirm `FLAG_SECURE` on the shell tabs under the new window themes (not run: no device).
  - A release-build smoke test (`flutter build apk --release --obfuscate --split-debug-info`) by the orchestrator confirms the gallery redirect and the silent logger in release.
