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
