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
