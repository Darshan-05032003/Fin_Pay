# Decisions

Every judgement call made during the UI upgrade, with the reason. Newest at the bottom of each section.

## Toolchain

### D-001: Pin Flutter 3.47.9 everywhere
- **Context:** CI (`subosito/flutter-action`, `channel: stable`) floats to the newest stable (3.47.9 / Dart 3.13.7), while the dev machine had 3.41.9 / Dart 3.11.5. Formatter and lint differences between SDKs can make a commit green locally and red in CI.
- **Decision:** Use Flutter **3.47.9** for local builds and CI. It is the newest stable line, it is mature (released 2026-08-12, with 9 hotfixes since) and it still receives fixes. The previous line, 3.44, stopped getting patches on 2026-08-06.
- **How:** `environment: flutter: ">=3.47.9"` in `pubspec.yaml` as a floor. Locally the SDK lives in `~/flutter_sdks/3.47.9`, so the machine's global SDK is untouched.
- **CI is not modified** (owner's instruction). `.github/workflows/main.yml` keeps `channel: stable`, which today resolves to 3.47.9, the same as local. A floor rather than an exact pin is deliberate: an exact pin would make CI's `pub get` fail when a newer stable ships.
- **Risk:** when Flutter publishes a new stable, CI moves to it before this repo does. If that release changes formatter or lint output, CI can go red until the repo is upgraded. Mitigation: when CI fails on a new stable, upgrade the local SDK to match.
- **No pull requests or Copilot reviews.** Every change goes straight to `main` with `git push origin main`.

### D-002: Upgrade all dependencies to their latest majors
`flutter pub upgrade --major-versions` on 3.47.9: go_router 18, flutter_bloc 9, equatable 3, intl 0.20, animations 3, smooth_page_indicator 3, shimmer 4, injectable 3, very_good_analysis 11, cupertino_icons 2. The only package held back is `build_runner` (2.16; `injectable_generator` caps it). Packages the app never imports are removed during F0/F1, once their usage is confirmed (see `UI_AUDIT.md`).

### D-003: Use CRED's `neopop` package as the NeoPOP rendering base
`neopop` 1.0.2 (publisher cred.club, Apache-2.0) was last published in 2022, but it compiles and passes a widget test on Flutter 3.47.9. Per the spec we prefer it for 3D buttons and surfaces. It is wrapped behind `lib/design_system/` components (`FpButton`, `FpSurface`), so screens never import it directly: if it breaks on a future SDK, only the wrappers change. The wrappers add what the package lacks: `Semantics`, ≥ 48dp targets, reduce-motion, the injectable `HapticService` and double-tap guards.

## Process

### D-004: Wave 1 runs sequentially
The build machine has 15 GiB of RAM, with ~1.4 GiB free while an emulator is running. The spec requires ≥ 16 GiB to run Wave 1 in parallel, so agents C → D → E → F run one after another, each in its own worktree.

### D-005: The preflight commit is pushed together with F0
The spec asks for a push right after the preflight commit, and also that every push keeps CI green. The preflight commit alone would be red (the baseline fails format, analyze and test), so it is committed locally and pushed with the F0 "baseline green" commit. No history is rewritten; the commits stay separate.

### D-006: Gradle wrapper uses the `-bin` distribution
The wrapper's download of `gradle-8.14-all.zip` (230 MB, sources and docs included) stalled repeatedly on this network and restarts from zero each time. `gradle-8.14-bin.zip` is the same Gradle without IDE sources, which the build never needs. One-line change in `android/gradle/wrapper/gradle-wrapper.properties`.

## F1 Foundations (Agent A)

### D-017: Money is an `int`-paise value type, formatted by `intl` en_IN
`lib/core/money/money.dart`. Every constructor, parser and operator works on `int paise`; `+`, `-`, unary `-` and `*` throw `MoneyOverflowException` instead of wrapping past int64. `Money.parse` is deliberately tolerant of what people paste (₹/Rs/INR markers, Indian or western grouping, NBSP, bidi *marks*, any Unicode `Nd` digit) and deliberately strict on what can change meaning (bidi *overrides*, exponents, two decimal points, letters/emoji). A third decimal rounds half away from zero, matching `Money.rupees(double)`, which adds a 1e-9 epsilon so `1.005` becomes 101 paise and not 100. Formatting uses `NumberFormat('#,##,##0', 'en_IN')` on the integer rupee part (exact for the whole int64 range) and appends the paise by hand, so `Money.max.format()` is exact. `rupees` (a `double`) exists for the legacy `CredNumberCounter` only and is documented as display-only.

### D-018: Schema v2 recreates every table instead of `ALTER`ing
SQLite cannot drop a column before 3.35 and never changes a column's affinity, so a `REAL` column would keep returning doubles. v1→v2 creates `*_v2` tables, copies rows with `CAST(ROUND(amount * 100 ± 1e-6) AS INTEGER)` (the epsilon fixes `2.675` → 268, which plain `ROUND` gets wrong because the stored double is 2.67499…), drops the old table and renames. Every step uses `IF EXISTS`/`IF NOT EXISTS`, and sqflite runs `onUpgrade` inside one exclusive transaction with `user_version` set last, so a crash mid-migration rolls back and the next open simply runs it again (tested with an injected `onMigrationStep` fault).

### D-019: `DatabaseService` removed; `AppDatabase` + `SqfliteLocalDataSource` replace it
Nothing but the data source needed the old singleton. `AppDatabase` (lib/data/database) owns the connection, the factory (ffi in tests), the path and the migrations; `SqfliteLocalDataSource` is the only class that writes SQL. Blocs no longer touch the database; they go through repositories.

### D-020: Transactions are idempotent per client-generated `idempotencyKey`
`transactions.idempotencyKey` has a unique index, and `saveTransaction` runs `SELECT key → INSERT → UPDATE users.balance` inside one exclusive sqflite transaction, returning `recorded | duplicate | insufficientBalance | noUser`. The balance check lives in the data source rather than the use case because it must be atomic with the insert. A `TransferDraft` carries the key from the amount screen, so a double-tap on "pay", a back-and-retry or a restored process cannot create two rows. `saveTransactions` (bulk, `INSERT OR IGNORE`) is for seeding/import/stress and never touches the balance.

### D-021: go_router 18 stays; `Navigator.pushNamed` is gone
go_router was already a dependency and gives us a testable redirect, typed extras and a single page-transition hook. `AppRedirect.resolve` is a pure function (route set × session state × debug flag) with a full matrix test; `AppRouter.build` wires it to `SessionCubit` through `GoRouterRefreshStream`. `/gallery` exists in debug builds only (redirected to home/login in release). `AppPageTransitions.page` is the only place routes build pages; F2 swaps `AppPageTransitions.builder` for real transitions. Route arguments are typed (`TransferDraft`); an untyped `extra` shows a guard screen instead of inventing defaults. The old `RouteGuard` was dead code and is deleted. Tabs still `context.go` between four top-level routes; the `StatefulShellRoute` shell is F4/F7 work.

### D-022: PBKDF2-HMAC-SHA256, 10,000 iterations, 16-byte salt, in pure Dart
`package:crypto` has HMAC-SHA256 but no PBKDF2, so `PasswordHasher.pbkdf2` implements RFC 8018 §5.2 (verified against the public `password`/`salt` test vectors). 10k iterations costs ~30 ms in the JIT test VM and well under a second on a phone, which is plenty because the real defence is the lockout (5 failures → 30 s, persisted per e-mail in secure storage so a restart does not reset it). Argon2/scrypt would need a native plugin; not worth it for an on-device demo credential. The demo account's `(salt, hash)` pair is a precomputed constant in `lib/core/auth/demo_credentials.dart`; the plaintext lives only in the README and in tests, and a unit test greps `lib/` for it and for the owner's secret regex.

### D-023: Session is a persisted marker in secure storage, not "a user row exists"
The old `RouteGuard` treated the seeded demo user as "logged in". Now `AuthRepository` writes `session:userId` on sign-in, `SessionCubit.restore()` reads it before the router is built, and `restoreSession` returns null if the user row is gone. Sign-out only clears the marker; the user's data stays on the device.

### D-024: Card PAN and CVV live in secure storage, the database keeps the mask
v1 stored full card numbers and CVVs in plaintext SQLite (High). v2 drops both columns; `CardRepositoryImpl` writes `{cardNumber, cvv}` to `SecureStorage` under `card:<id>` and re-attaches them on read. Existing v1 rows keep only `**** **** **** 1234`: their PAN/CVV are discarded by the migration rather than copied into another plaintext place. The remaining plaintext at rest (names, e-mail, balances, transaction titles) is documented in `SECURITY_REVIEW.md`; SQLCipher is out of scope for F1.

### D-025: Platform plugins behind interfaces with fakes and a DI `overrides` hook
`lib/core/platform/`: `FlutterHapticService` (HapticFeedback + vibration, gated by the haptics setting), `LocalAuthBiometricAuthenticator`, `SensorsPlusMotionSensor` (`Stream<Tilt>` normalised to ±1 g), `MethodChannelScreenProtector` (`fin_pay/screen_protector`, Kotlin side in `MainActivity.kt`, no-op off Android), `FlutterSecureStorageAdapter`. Every one has a `Fake…` in `lib/core/platform/fakes/` (exported together from `fakes.dart`) and `di.init(overrides: DiOverrides(...))` swaps them in. `MainActivity` becomes a `FlutterFragmentActivity` because `local_auth` needs a `FragmentActivity`.

### D-026: `injectable`, `build_runner`, `lottie`, `animated_text_kit`, `flutter_animate`, `http` removed
DI stays hand-written (`injection_container.dart` is 150 lines and readable); `injectable` was declared but never used, and dropping it also drops `build_runner` and the `build_runner` version cap. `lottie`, `animated_text_kit`, `flutter_animate` and `http` (only used by the dead `NetworkService`) are imported nowhere. `flutter_staggered_animations` and `url_launcher` are still imported by screens owned by other agents, so they stay; `animations`, `shimmer`, `confetti`, `smooth_page_indicator`, `flutter_svg` stay for F2. Added: `crypto`, `clock`, `flutter_secure_storage`, `local_auth`, `sensors_plus`.

### D-027: Text scale clamped to 1.3 app-wide, reduce-motion forces `disableAnimations`
`AccessibilityScope` (lib/app.dart) replaces the forced `TextScaler.noScaling`: the system scale is honoured up to 1.3× (the factor the goldens will be checked at), and the reduce-motion setting ORs into `MediaQuery.disableAnimations`, so every animation that checks `MediaQuery.disableAnimationsOf` and the page transitions degrade to a cut without each widget knowing about settings.

### D-028: `Logger` is silent in release and redacts before printing
All four levels return early under `kReleaseMode` (previously `error` printed in release). `Logger.redact` masks 13–19-digit runs that pass Luhn (so ids and timestamps survive), `cvv` fields and `password|pin|otp|token` values in `k: v`, `k=v` and JSON forms. `--obfuscate --split-debug-info` is documented in `SECURITY_REVIEW.md` and the README.

### D-029: `UserService` kept as a static facade over the repositories
Screens owned by agents C–F still call `UserService.*`. Rewriting them is their work, so the facade stays, stripped of every credential and of `loginUser`; it resolves repositories through GetIt and holds no state. It is deleted when the last screen is migrated.

## Design system (F2)

### D-007: Shimmer is a plain gradient sweep, not the `shimmer` package
`package:shimmer` wraps every block in a `ShaderMask`, which costs a `saveLayer` per skeleton; a loading screen with 50 rows would pay for 200 layers per frame. `FpSkeleton` paints a `LinearGradient` whose alignment slides across the box (no mask, no layer) and `FpSkeletonGroup` shares one `AnimationController` between every block under it. Measured: 200 blocks, 1 ticker, 2.4 ms per frame on the test host. The `shimmer` dependency stays until the last screen using `SkeletonLoader` is migrated.

### D-008: How the `neopop` package is wrapped
`FpButton` uses `NeoPopButton` only as a painter: it passes `onTapUp: null` (so the package attaches no gesture handling) and `disabledColor` equal to the face colour (so the "disabled" paint path renders the real face). The wrapper owns the `GestureDetector`, translates the face by `depth × t` with its own controller (60 ms collapse, `FpSprings.press` release), plays the `medium` haptic on press down, adds `Semantics`, the ≥ 48 dp constraint, reduce-motion and `FpSubmitGuard`. `FpSurface` uses `NeoPopCard` for the edge faces. Both reserve `depth` pixels of padding on the right and bottom because the package paints its edges outside the widget's box. Edge colours come from `FpEdge` tokens rather than the package's HSL derivation, so goldens are deterministic.

### D-009: Golden tolerance 0.5 % and real fonts
`test/flutter_test_config.dart` loads Manrope and Instrument Serif with `FontLoader`, so goldens show the real type, and installs an `FpGoldenComparator` that accepts up to 0.5 % differing pixels (anti-aliasing differences between Linux hosts) while still failing on real layout changes. Material icons are not loaded in tests, so icons render as boxes in goldens; that is stable and intentional. Baselines were generated once with `--update-goldens` and committed.

### D-010: Hidden amounts are masked, not blurred, by default
`FpAmountText.hide` defaults to `mask` (`₹••••••`): a blur leaks the digit count and magnitude in screenshots and costs an `ImageFilter` layer. `FpAmountHide.blur` exists for the home-screen peek interaction only.

### D-011: Entrance delays are `Interval`s, not timers
`FpEntrance` runs one controller over `delay + duration` and maps the delay to the flat start of an `Interval`. No `Future.delayed` / `Timer` can fire after dispose, a staggered list is one ticker per child with nothing pending, and widget tests pump deterministically (the old `CredSlideIn` started with `Future.delayed`). `FpStagger.delays` compresses so the last child starts by 480 ms regardless of list length.

### D-012: Bottom sheet is a custom `PopupRoute` with a single-instance guard
`showModalBottomSheet` cannot run on a spring or follow the finger with velocity-based release. `_FpSheetRoute` overrides `didPush` to drive the route's own controller with `FpSprings.sheet`; dragging edits the same controller, and release either springs back or springs out and pops (a status listener handles the pop because `animateWith` reports `completed` even when the target is zero). `FpBottomSheet.show` returns `null` while another sheet route is active so a double tap never stacks two sheets.

### D-013: Display styles fall back to Manrope for the rupee sign
Instrument Serif has no U+20B9 glyph. All `display*` styles carry `fontFamilyFallback: ['Manrope']`, so `₹` renders from the bundled UI font everywhere instead of depending on the OS fallback.

### D-014: `lib/widgets/neopop_button.dart` deleted with the other dead widgets
The audit marked it KEEP→ (redesign), but it had zero usages and its replacement (`FpButton`, `FpSurface`) now exists, so keeping it would leave two things doing the same job. Files still imported by screens stay until Wave 1 (list in `docs/DESIGN_SYSTEM.md`, "Pending removals").

### D-015: `FpPressable` is feedback only; submissions go through `FpButton`
Cards, rows and avatars need press feedback but must not swallow repeated taps (a list row tapped twice should navigate twice if the first navigation was cancelled). Only `FpButton` carries `FpSubmitGuard`; the security test documents that `FpPressable` fires on every tap.

### D-016: Odometer rolls in the direction of the overall change
`FpOdometer.plan` compares the digit strings numerically and rolls every column upward on an increase (wrapping 9 → 0) and downward on a decrease, with new leading columns sliding in from blank. The pure planner is unit-tested ("1,234" → "9,876"), and one controller with per-column `Interval`s (30 ms stagger from the right, capped at 200 ms) drives all columns.

## F3 Onboarding + Auth (Agent C)

### D-030: The demo OTP is the last six digits of the phone number
There is no SMS backend, so the verification code is simulated locally. The code is derived from the mobile number typed at sign-up (`CreateAccountCubit.otpFor`), which keeps the demo self-explanatory (documented in the README) without printing the code on screen or logging it. The code is held privately by `OtpCubit`/`CreateAccountCubit` and is never a field of any state; the comparison is constant-time; five wrong codes lock the step and resending never resets the attempt count. Alternatives rejected: a fixed `123456` (looks like a backdoor in screenshots) and showing the code in a debug banner (would ship in release unless guarded).

### D-031: Sign-up re-keys the single on-device account
The data layer is single-user (`getUser()` is `LIMIT 1`). Creating an account therefore stores a new salted hash for the new email, updates the existing user row's name/email/phone (keeping the balance, cards and transactions, so the demo stays explorable) or inserts a row with the demo opening balance when the device has none, then signs in. Deleting the demo user would break the F1 seeding assumptions and wipe the demo data; a multi-user schema is out of scope for a demo.

### D-032: The password lives in a shell-scoped `CreateAccountCubit`, not in route `extra`
F1 flagged the plaintext password travelling through `GoRouter` `extra` (Medium). `/create-account` and `/verification` now sit under one `ShellRoute` whose builder provides a `CreateAccountCubit`; the verification step reads the pending sign-up from it, and the cubit is closed (password wiped) when the shell is left. The password is a private field, never part of `CreateAccountState`, so `toString`/`props` never carry it; the same holds for `LoginCubit`. Opening `/verification` with no pending sign-up (deep link, process death) shows a "start again" guard instead of inventing a session.

### D-033: Countdowns run on the injected `Clock` and clamp clock jumps
`OtpCubit` (30 s resend) and `LoginCubit` (lockout remaining) compute the remaining time from a deadline against `Clock.now()` on a 1 s `Timer.periodic`, so `fake_async` drives them in tests and `tester.binding.clock` in widget tests. A clock jump forward ends the countdown; a jump backwards is clamped to the original length (the lock can never grow past what the repository granted), so the user is never stuck.

### D-034: `FLAG_SECURE` is reference-counted
`SecureScreen` wraps login, create account and verification. Pushing create account over login must not switch protection off when it is popped, so the wrapper counts mounted instances and calls `ScreenProtector.enable()` on 0 → 1 and `disable()` on 1 → 0 only. The login and sign-up screens also re-obscure a revealed password on `inactive`/`hidden`/`paused`.

### D-035: Onboarding "seen" lives in `AppSettings`, and the redirect reads it
`onboardingSeen` and `biometricEnabled` were added to `AppSettings` (shared_preferences). `AppRedirect.resolve` takes `onboardingSeen` and sends `/onboarding` to `/login` once seen; the router merges the `SettingsCubit` stream into its refresh listenable so the redirect re-runs when the flag flips. The welcome splash stays as the root and adapts its calls to action instead of being skipped.

### D-036: Page transitions through `AppPageTransitions.fp`
`AppPageTransitions.builder` now defaults to `fp`, a route → `FpTransitionKind` map: shared-axis X for the auth steps (onboarding, login, create account, verification, fingerprint, reset) and fade-through for the splash, home and anything unlisted (tabs). Tests that need a cut keep `AppPageTransitions.fade`.

### D-037: `FpOtpField`, `FpCountdownRing` and `FpDrawnCheck` join the design system
All three are generic (F5's success screen needs the drawn check; any timed step can use the ring; the OTP field has no auth-specific knowledge), so they live under `lib/design_system/` with gallery sections, goldens and tests. The OTP field is one hidden `TextField` (digits-only formatter, `oneTimeCode` autofill) behind six painted cells rather than six fields: paste and autofill then need no cross-field plumbing and backspace naturally moves back.

### D-038: Sign-up illustrations are three `CustomPainter` layers per page
No assets: each onboarding page paints three NeoPOP glyphs (flat face + solid edge) at speeds 0.35 / 0.6 / 0.85 of the page; `OnboardingParallax.layerShift` (pure) counter-translates each layer by `(page − index) × width × (1 − speed)`, read from the `PageController` in one `AnimatedBuilder` per illustration (no per-frame `setState`). Reduce-motion freezes the layers and makes "next" jump instead of animate.

## F4 Home + Cards (Agent D)

### D-039: The four tabs live in a `StatefulShellRoute.indexedStack`
`AppRouter` wraps home, statistics, cards and profile in one shell (`lib/screens/shell/app_shell.dart`) so every tab keeps its scroll position, fanned stack and loaded state across switches. The bar is `FpBottomNav`; tab switches are cuts (an `IndexedStack` swap), which reads as "the bar is the app" and avoids a transition that would replay entrances; pushes out of a tab (add card, card details, transfer, transactions) keep the design-system transitions. The Android back rule lives in a `PopScope`: on a non-home tab back returns to home (`goBranch(0)`), on home it leaves the app (`popRoute()` returns false). Re-tapping the current tab fires `TabReselect`, which home uses to scroll to the top. Add card and card details moved to `/cards/add` and `/cards/:id` and are pushed on the **root** navigator (`parentNavigatorKey`) so they cover the bar; `AppRoutes.isProtected` treats everything under `/cards/` as protected so a deep link with any id still needs a session.

### D-040: `FLAG_SECURE` follows the visible tab
`SecureScreen` gained an `active` flag; the shell keeps one instance active while home or cards is the visible branch, so the recents thumbnail is blank on the balance and card tabs but not on statistics/profile (Agent F decides for those). The reference count from D-034 still applies: card details and add card are pushed over the shell and hold their own count, so popping them never switches protection off under the home tab.

### D-041: The app-wide card list never holds the PAN or CVV
`CardBloc(maskSensitive: true)` (the DI registration) strips the number to its mask and the CVV to an empty string on every load and in the `CardAdded` effect; the full values go through `ICardRepository.addCard` to secure storage and come back only through the new `ICardRepository.readCvv(cardId)` for a timed reveal. The default stays `false` so the F1 bloc tests are unchanged. Dart strings are immutable and cannot be zeroed, so "cleared from memory" means every reference is dropped (`AddCardCubit._cvv = ''` on success and close, `CvvRevealCubit._cvv = null`, the add-card controllers cleared on dispose) and nothing retains them; a native secure-string type is out of scope.

### D-042: CVV reveal is a five-second window on the injected `Clock`
`CvvRevealCubit` fetches the CVV on tap/long-press, shows it with a countdown ring, masks it after `ttl` (5 s, `Timer.periodic` on the injected `Clock` so `fake_async` drives it; a clock jump backwards cannot extend the window), on `hide()` (the screen calls it when the app goes `inactive`, when details are opened and when the stack collapses) and on close. The digits are a private field, never a state property, so `BlocObserver`/`toString` never carry them; `Logger.redact` masks `cvv: 123` should anyone log one. A second reveal of the same card restarts the window without touching storage.

### D-043: Hide balance masks and is one persisted write per change
The eye on the home header calls `SettingsCubit.toggleHideBalance()`; the header, the recent rows and the card-details rows read the setting, so every amount on the home/cards screens is `₹••••••` at once. Mask rather than blur, per D-010 (a blur leaks magnitude in screenshots and costs a layer). The settings cubit already debounces nothing and writes once per change, which the stress test confirms (1,000 taps → 1,000 writes, final state consistent).

### D-044: Only the last four digits ever reach the clipboard
Card details offers "Copy last 4" and nothing else: there is no "copy full number" action at all, so the PAN cannot land in the clipboard (which every app can read on older Android versions and which keyboard clipboard managers persist). The masked number on screen is `•••• •••• •••• 1234`.

### D-045: Card art is code-drawn and labels are neutral text
`PaymentCardArt` paints a NeoPOP face (solid token colour, flat pattern, bottom/right edge) per network: diagonal bands for Visa, concentric arcs for Mastercard, chevrons for RuPay, a dot grid otherwise; a generic EMV-style chip; the network as a plain `label` text ("Visa", "Mastercard", "RuPay") in the token typography. No wordmarks, no logos, no assets. BIN detection: Visa 4; Mastercard 51–55 and 2221–2720; RuPay 60, 65, 81, 82, 508. American Express exists in `CardType` for legacy rows but is not detected and cannot be added (16-digit, 3-digit-CVV flow only).

### D-046: Tilt comes from a damped sensor stream or raw pointer events
`FpTiltCard` takes an `FpTiltController`; the cards tab subscribes to `MotionSensor.tilt` only while it is the visible tab and reduce motion is off (so the accelerometer is not sampled from an offstage tab), pushes samples through `FpTiltMath.damp` (factor 0.25) to kill jitter, and cancels the subscription on tab change and dispose. When `isAvailable` is false the card tilts under the finger through a `Listener` (raw pointer events never enter the gesture arena, so the carousel still swipes) and springs back on release. At rest the transform is the identity (no perspective entry), which keeps hit-testing and semantics rects exact and lets the compositor skip a 3D layer. Reduce motion renders the child flat with no sheen.

### D-047: Freeze is local and "recent card payments" are payments
The ledger has no card column, so card details lists the newest `TransactionType.payment` rows under "Recent card payments" and says so in the code; a per-card filter needs a schema change (F6/F7). The freeze toggle is a `CardDetailsCubit` flag for the screen's lifetime: persisting it needs a column or a settings key, and a demo "frozen" card that still pays would be misleading; it is clearly labelled as blocking payments "on this device".

### D-048: Pull-to-refresh waits for the blocs
`FpRefreshIndicator` is built on scroll notifications (no `RefreshIndicator`), so it works with clamping and bouncing physics and draws its own plunk tile + arc; `refreshHome` dispatches the three load events and awaits each bloc's first non-loading state (10 s cap), so the indicator holds until data is back instead of closing immediately as the legacy screen did (UI audit 2.8). A throwing `onRefresh` is reported through `FlutterError.reportError` and the glyph retracts; it never takes the screen down.

### D-049: Flip card draws the back un-mirrored and switches faces at 90°
`FpFlipMath.transform` counter-rotates the back face by π (the legacy `Card3DFlip` showed it mirrored, UI audit 2.9) and swaps faces at `t = 0.5`; add card uses it to flip the preview while the CVV field has focus, and the stack/details use it for the CVV back. Under reduce motion the face swaps without rotation.

## F5 Payments (Agent E)

### D-050: A two-phase simulated bank behind `PaymentGateway`, with demo triggers for every outcome
`lib/domain/payments/payment_gateway.dart` defines `PaymentGateway.authorize` (before the ledger is touched; a decline costs nothing) and `settle` (after the ledger recorded the debit; a timeout here is the classic "debited but unconfirmed" case idempotent retries exist for). `SimulatedPaymentGateway` is registered in GetIt (`DiOverrides.paymentGateway` swaps in `FakePaymentGateway` for tests) and simulates 900 ms of latency per phase with a plain `Timer`, which `fake_async` and the widget-test clock control; the reference on the receipt is `FP` + ten hex characters of the key's SHA-256, so a retry shows the same reference. Two of the eleven invented demo contacts exist only to reach the failure paths from the UI:

README-ready: demo payment outcomes
- **Success** – pay any contact (e.g. Priya Raghavan): bank → ledger → bank, confetti and receipt.
- **Declined (failure, nothing debited)** – pay "Test Decline" (`test.decline@fail`): the bank declines before the ledger; the failure screen offers "Edit payment" and "Back to home".
- **Timeout then already paid (idempotent retry)** – pay "Test Timeout" (`test.timeout@flaky`): the ledger records the debit, the bank's first confirmation times out, the failure screen offers "Retry"; the retry reuses the same idempotency key, the ledger answers "duplicate", the bank confirms, and the success screen says "Already paid" with exactly one row and one debit.
- **Insufficient balance (ledger rejection)** – the amount screen blocks amounts over the balance, so this path fires only when the ledger disagrees with the screen: a stale balance or a crafted `/transfer-review` extra (D-052). The widget tests push such a draft; the failure screen shows "Insufficient balance" with "Edit amount".
- **Storage failure / unreachable bank** – not reachable from the demo data; covered by `FakePaymentGateway(throwOnAuthorize: true)` and a failing repository in the tests.

### D-051: Processing and failure are states of the review route; success is its own route that takes a `PaymentReceipt`
One `PaymentCubit` owns a payment attempt for the lifetime of `/transfer-review`: idle → authorizing → recording → settling → success | failure. The processing panel (`FpProcessingRing` + phase label) and the failure view (`DrawnCross` + `FpShake` + Retry / Edit / Back to home) replace the summary in place, so "Retry" is a method call on the same cubit with the same idempotency key and never a navigation round trip or a second swipe. Success pushes `/transfer-success` with a `PaymentReceipt` (draft + bank reference + time + `alreadyPaid`) as the typed extra, replacing the review so back from success cannot resubmit; a bare `TransferDraft` on the success route shows the guard screen, because a crafted extra must not render a "Payment sent" page for a payment that never happened. The `TransferDraft` contract is kept (`receipt.draft`). `/transfer-failure` was not added.

### D-052: The ledger is the authority on balance; the review refuses only structurally invalid drafts
`PaymentCubit.pay` rejects a draft whose amount is not positive or exceeds `AmountRules.maxPerTransfer` (₹1,00,000), or whose key, name or VPA is blank, before the bank or the ledger sees it ("Invalid payment", Edit amount). It does **not** re-check the balance: the legacy screen compared against a `UserService` read that could be stale and then wrote `-transferAmount`, so a negative draft would have *credited* the account. Now the ledger's exclusive transaction decides (`insufficientBalance` → failure with "Edit amount"), the sign is fixed by the cubit, and the tampering cases are tests (`payment_cubit_test.dart` "tampered drafts", `transfer_review_screen_test.dart`).

### D-053: The amount is a keypad model, displayed through the design-system odometer
`AmountInput` is canonical text (`''`, `'12'`, `'12.'`, `'12.50'`): seven integer digits (₹99,99,999), two decimals, one point, no leading zeros, backspace and long-press clear. Pasted text (long-press on the amount) goes through `Money.parse`, so fullwidth / Arabic-Indic / Devanagari digits, grouping and `₹`/`Rs` prefixes are normalised, and letters, emoji, exponents, bidi overrides, negative or zero values, int64 overflow and 100,000-character pastes are rejected (shake + error haptic); the screen also truncates a paste to 64 characters before parsing. The display is `FpAmountText`, which already rolls per digit (`FpOdometer.plan`: right-aligned columns, direction follows the change, so backspace rolls back) rather than a second odometer; the cost is that the display always shows two decimals (`₹12.00` while typing `12.`). The inline error shakes only on the transition into an error state, not on every key while in it.

### D-054: Contacts are a fixed demo list, ranked by the ledger's recent recipients
`IContactRepository` / `DemoContactRepository` (eleven original names; nothing reads the device address book). `TransferCubit` loads contacts, the live balance (`IUserRepository.getCurrentUser`, not the possibly stale `UserBloc`) and the last 20 transactions; `ContactSearch.recentRecipients` takes the distinct `sendMoney` recipients newest first (at most five, exact normalised name match) and `rank` puts them first in recency order, then the rest in list order. Search normalises case, whitespace, zero-width and bidi-control characters and matches name or VPA.

### D-055: No amount or VPA in `toString`, logs or the clipboard
`TransferState`, `PaymentState`, `PaymentRequest`, `PaymentReceipt`, `Contact` and `AmountInput` print only their status / id / reference, so `BlocObserver` and route logs never carry money or addresses; `PaymentState` does not even hold the draft (the cubit does). The payment files contain no `print`/`debugPrint`/`Logger` call (enforced by `log_hygiene_test.dart`). "Share receipt" opens an `FpBottomSheet` with the plain-text receipt and a "Copy receipt" button: amount, payee name, **masked** VPA (`pr•••••@okaxis`), bank reference, time, note and status; never the full VPA, an account number or the idempotency key. No share plugin was added (the owner can wire `share_plus` to the same text later).

### D-056: `FpSwipeToPay` contract
Pure `FpSwipeMath`: travel = track − thumb − 2 × inset; confirm at ≥ 85 % of the travel or a fling ≥ 1,200 px/s from ≥ 50 %; ticks at 25/50/75 % play a `selection` haptic on each forward crossing (none backwards); released early the thumb springs back on `FpSprings.slider`. Confirm springs the thumb to the end, plays `heavy`, and calls `onConfirmed` once through `FpSubmitGuard`; the slider stays locked while `processing` is true and springs back (unlocked) when the parent clears it, and if the parent never locks it the thumb returns after the action completes (decided on the next frame so a synchronous `setState(processing = true)` wins). Screen readers get one button node ("double tap to pay") that triggers the same guarded confirm; under reduce motion the slider is replaced by a large `FpButton` with the same label, loading state and callback.

### D-057: Back and backgrounding mid-payment
While a payment is in flight the review's `PopScope` refuses to pop and shows "Payment in progress" (the back arrow is disabled too); the cubit keeps running through `paused`/`resumed`, so backgrounding neither cancels nor duplicates (`transfer_review_screen_test.dart` "mid-payment"). Process death mid-flight is handled by the key: the next attempt for the same draft is reported "already paid" by the ledger (the simulated bank's "flaky" memory is in-process, so after a restart a `@flaky` payee times out once more and then resolves).

### D-058: After success: balance refresh and one notification; the note is not persisted
`PaymentCubit` dispatches `LoadUserEvent` to the app-wide `UserBloc` (home shows the new balance) and an `AddNotificationEvent` ("Payment sent", amount and name, no VPA) only when the ledger *recorded* the row, never for a duplicate. The ledger has no note column, so the note lives in the draft and the receipt only (a column is a schema bump for F6/F7). `TransactionBloc` already reloads the list after `TransactionAdded`.

### D-059: Blocs never emit an effect after close
The harness exposed `NotificationBloc._onAdd` adding to its closed effects controller when the real sqflite write finished after the screen was torn down (F1 pattern). `NotificationBloc` and `TransactionBloc` now route effects through an `_emitEffect` that checks `isClosed`; one line each, additive.

## F6 Insights + Activity (Agent F)

### D-060: `fl_chart` draws the charts; one entrance controller animates them
pub.dev check at build time: `fl_chart` 1.3.0, published 2026-10-21, Flutter ≥ 3.27.4, `equatable` ≥ 2.1 < 4 (we are on 3.x), actively maintained. Added with `fl_chart: ^1.3.0`. The package draws the bars, the line and the donut from token colours (`FlGridData(show: false)`, `FlBorderData(show: false)`, no package defaults reach the screen); it does **not** animate the entrance: one `AnimationController` in `_StatsViewState` (400 ms, `emphasizedDecelerate`) scales every bar's `toY` by `t`, reveals the line through a `ClipRect` whose width is `t × width` (the line "draws on"), and feeds the donut `share × t` plus a background-coloured remainder so it sweeps clockwise from twelve o'clock. The controller restarts on every successful load (`StatsState.revision`), so a period switch re-animates; under reduce motion it jumps to 1 and `fl_chart` gets `duration: Duration.zero`. The bar tooltip is our own `FpSurface` driven by `BarTouchData(handleBuiltInTouches: false)` so it is deterministic in tests; the line uses the package tooltip styled with tokens. A CustomPainter trio was the alternative; it would have cost ~300 lines for axes and hit-testing the package already does.

### D-061: Transactions are paged by limit/offset, 50 rows at a time
`TransactionsCubit` pages through the existing `ITransactionRepository.getTransactions(limit, offset, type)`: the next offset is the number of rows fetched so far minus the rows deleted since (an undo adds one back), so a delete never skips or repeats a row; `loadMore` fires when the list is within 600 px of its end (`TransactionsMath.nearEnd`), is refused while a page is in flight or while searching, and keeps the rows on a failed page (the next scroll retries). Every request carries a generation; an answer for an older generation (the filter or the query changed meanwhile) is dropped. Measured at 100k rows: first page 0–3 ms, the page at offset 99,950 30 ms (LOAD_TEST_REPORT F6), so OFFSET is fine for this product's ledger sizes; keyset paging (the F1 recommendation for > 400k rows) would need a cursor method on the data source and stays listed under scope for improvement. Search goes to `searchTransactions` (parameterised `LIKE … ESCAPE '\'`), is not paged and is capped at 50 rows by the data source; the cubit debounces 300 ms, trims and bounds the query to 200 characters (D-068).

### D-062: Filter chips are ledger types, pushed into the query
All / Sent (`sendMoney`) / Received (`receiveMoney`) / Payments (`payment`) / Card (`topUp`, the only card-backed movement the ledger records; there is no card column, D-047). The type goes into the SQL `WHERE` through the new optional `type` parameter on `getTransactions` and `searchTransactions` (additive; the repository only forwards it when set, so existing stubs keep matching), instead of filtering a page client-side and showing sparse pages.

### D-063: Delete is optimistic, the balance is not reverted, undo re-inserts idempotently
Swipe → "Delete" removes the row at once and calls `deleteTransaction` (the ledger rule from F1: deleting a row does not revert the balance; it is a bookkeeping action, not a refund). The row waits in an undo buffer; "Undo" on the toast calls `addTransactions([row])`, which is the bulk importer: it does not touch the balance and skips an existing `idempotencyKey`, so a replayed undo (double tap, two toasts) cannot duplicate the row. When the toast closes without the action the cubit forgets the row. After a delete or an undo the app-wide `TransactionBloc` gets `LoadTransactionsEvent` so the home tab's recent rows stay in step (it still reads the whole ledger, F4 compromise).

### D-064: Notification dismiss deletes at once; undo re-adds; read state is an UPDATE
A full swipe (or the tray's "Dismiss") sends `DeleteNotificationEvent`; the bloc's `NotificationDeleted` effect carries the row and the screen offers Undo, which sends `AddNotificationEvent(row)`. Storage replaces by id and the bloc's add handler now de-duplicates by id and inserts in storage order (newest first, ties first), so a replayed undo keeps one row in its place. Chosen over a pending-delete buffer so that a dismissed row is gone even if the process dies before the toast expires (what the user saw is what is stored). Mark-read is `MarkNotificationReadEvent` / `MarkAllNotificationsReadEvent` over a new `INotificationRepository.markRead(ids)` (chunked `UPDATE … WHERE id IN (…)`, 500 ids per statement), which writes only the ids that are actually unread.

### D-065: `FpSwipeActionRow` contract
Design-system component (`lib/design_system/components/fp_swipe_action_row.dart`): the foreground follows the finger left (`DragStartBehavior.down`, so the slop distance counts and the row moves from the first pixel), reveals up to three 72 dp actions, snaps open at 50 % of the tray or on an 800 px/s fling, and — when `onDismissed` is given — keeps following past the tray and dismisses when released past 55 % of the row width (or flung past the tray); a non-dismissible row resists past the tray at 0.3. Release settles on `FpSprings.slider`; dismissal slides the row out over 250 ms and collapses its height over 250 ms before `onDismissed` fires once. Screen readers get every action and "Dismiss" as custom semantics actions on one labelled node (the tray tiles are excluded). Haptics: `selection` on crossing the open threshold either way, `light` on an action, `medium` on dismiss. `FpToast.show` gained `actionLabel`/`onAction` (runs once, closes the toast, `handle.actionTaken`) for the undo flows. Only one row opens at a time is **not** enforced (an `FpSwipeActionController` can close a row; wiring a shared one is listed under scope).

### D-066: Statistics periods are local calendar ranges; overflow is an error state; the tab loads when shown
Week = the last seven calendar days (daily bars labelled Sun…Sat), month = the last thirty days (five six-day bars labelled by start date), year = the last twelve calendar months (monthly bars); the trend line has one point per calendar day (7 / 30 / 365–366). `StatsMath` counts calendar days (`dayNumber`, `addDays(y, m, d + n)`), never 24-hour spans, so DST days and zone offsets cannot move a row into the wrong bucket; the zone mapping is injectable (`toLocal`) so tests pin IST/UTC without touching the host. Sums are `Money` (int paise); a sum past int64 throws `MoneyOverflowException`, which the cubit turns into the error state "Amounts out of range" rather than wrapping. The donut groups debits by icon (type when the icon is blank), keeps the top five and folds the rest into "Other"; merchants are the top five titles. The query is `getTransactionsBetween(from.toUtc(), to.toUtc())` (new on `ITransactionRepository`, delegating to the F1 data-source method). Because the shell mounts all four tabs at start-up, the Stats tab loads the first time it is the visible branch, not on mount (it added a database read to every start and to every widget test that lands on home). The tab shows totals, so it joined `AppShell.protectedTabs` (`FLAG_SECURE`).

### D-067: Profile binds toggles straight to `SettingsCubit`; logout is a small cubit over `SessionCubit`
Haptics, Reduce motion, Hide balance and Biometric sign-in are `FpToggle` rows calling the existing `SettingsCubit` setters (optimistic, persisted, a failed save restores the previous value, F1); nothing new is stored. `ProfileCubit` (idle → confirming → signingOut → signedOut | failed) guards the confirmation sheet and calls `SessionCubit.signOut()` exactly once; the router's `refreshListenable` on the session stream performs the redirect to `/login`, and the widget test proves `/profile` and `/transactions` stay closed afterwards. The user row and `UserBloc` are left alone on logout (single on-device account; the next sign-in reloads through the existing F3 path). The About sheet carries the README attribution verbatim ("FinPay — inspired by CRED's NeoPOP design language; not affiliated with CRED"); the "Design gallery" row appears only in debug builds (`showGallery` defaults to `kDebugMode`). The parallax header sits *behind* the list in a `Stack` and follows the scroll at 0.4× through `FpParallax` (the primitive translates by `-offset × factor`, which is the convention for a background layer, not for a list item).

### D-068: Hostile input bounds on the data source
`SqfliteLocalDataSource.searchTransactions` cuts the query at 200 UTF-16 units before building the `LIKE` pattern (SQLite refuses patterns over 50,000 bytes with "pattern too complex", which turned a 100,000-character paste into a storage failure); a negative `limit` or `offset` becomes zero instead of SQLite's "unlimited" / "no skip"; `limit: 0` returns nothing. All three are tested at the data-source level with the real ffi database.

### D-069: Screens are scanned for raw colours, curves and magic durations
`test/unit/screens/screen_tokens_test.dart` walks `lib/screens/**` and fails on `Color(0x`, `Colors.`, `Curves.`, any `Duration(…seconds)` on a line that does not say "timeout", and on imports of the deleted `lib/widgets`, `lib/services`, `neopop`, `shimmer` or `flutter_staggered_animations`. Pure-logic files (cubits, states, maths, machines, rules, the transfer models) are exempt from the duration rule only. The one offender outside F6 was `spring_rise.dart`'s reduce-motion fallback (`Curves.easeOut`), now `FpMotion.standardDecelerate`.

## F7 App-wide polish + Wave 2 (Agent G)

### D-070: The app icon is drawn in Dart, not downloaded
- **Context:** the spec wants an original icon and splash through `flutter_launcher_icons` / `flutter_native_splash`, and the repo must not carry CRED assets.
- **Decision:** `tool/render_brand_assets.dart` is a `CustomPainter` rendered through `PictureRecorder.toImage` under `flutter test --dart-define=FINPAY_RENDER_ASSETS=true` (without the define it registers one skipped test; `dart run` cannot host `dart:ui`). It writes `assets/brand/{icon,icon_foreground,icon_monochrome,splash,splash_android12}.png`. Design: `FpColors.background` tile, an `accent` plate with the `accentDeep` offset edge (the NeoPOP "plunk" every surface in the app has), a bold geometric F cut out in `onPop`, a `success` chip. The same painter at different scales feeds the legacy icon, the adaptive foreground (62 % so it sits inside the 66 % safe zone), the monochrome themed icon (silhouette with the F punched out through `BlendMode.clear`) and both splash images (512 px for the layer-list splash so it stays ~120 dp on xxhdpi, 1152 px for the Android 12 icon).
- **Packages:** `flutter_launcher_icons 0.14.4` and `flutter_native_splash 2.4.8` (both verified on pub.dev, both maintained). `flutter_native_splash` is a runtime dependency because `FlutterNativeSplash.preserve/remove` runs in `main.dart`; the icon tool is dev-only.
- **Not changed:** `applicationId`, the label, `AndroidManifest.xml` (allowBackup=false and the single exported activity are untouched; verified by diff after both tools ran).

### D-071: The native splash hands over to the first Flutter frame without a flash
- Splash colour = `#0B0B0D` = `FpColors.background` = the scaffold colour of `FpTheme.dark()`; `test/widget/app_test.dart` pins the three together.
- `main.dart` calls `FlutterNativeSplash.preserve` before `di.init()` and `remove()` after `runApp`, so the splash covers the DB open, settings load and session restore, and the first frame is already the route the redirect chose (welcome or home; the same test asserts no intermediate screen for `SessionUnknown`, signed-out and signed-in).
- The generated `styles.xml` files are hand-adjusted after the tool runs: both `LaunchTheme` parents are `Theme.Black.NoTitleBar` and `NormalTheme.windowBackground` is `#FF0B0B0D` (the default `?android:colorBackground` under a light parent is white and would show behind the Flutter view during the hand-off and keyboard resizes). Re-running `flutter_native_splash:create` keeps `NormalTheme`; re-check the parents.

### D-072: The root theme is the design system; the legacy theme and helpers are deleted; the token scan covers the whole `lib/`
- **Found:** `lib/app.dart` still passed `AppTheme.lightTheme` (the legacy `lib/constants/theme.dart`: font "Inter", `0xFF0D0D0D` background, no `FpTokens` extension) while every widget test used `FpTheme.dark()`; screens looked right only because `context.fp` falls back to `FpTokens.dark`. Material-owned surfaces (scaffold, snackbars, app bars) were off-palette on the device.
- **Decision:** `theme` and `darkTheme` are both `FpTheme.dark()` (dark-only app, both slots equal so the system setting cannot swap palettes); `lib/constants/theme.dart`, `lib/core/error_handler.dart`, `lib/core/exception_handler.dart`, `lib/utils/constants.dart` and `lib/utils/helpers.dart` had no remaining users and are deleted.
- `test/unit/screens/screen_tokens_test.dart` now also scans `lib/app.dart`, `lib/main.dart` and `lib/routes` (screen rule: no colours, curves or magic durations), every other `lib/` folder (no colours or curves), and asserts that inside `lib/design_system` only `tokens/` and `theme/` define `Color(0x` and only `tokens/fp_motion.dart` defines a `Cubic`. The `Colors.` check is a regex that ignores `FpColors.` in comments.

### D-073: One explicit transition kind per route
- `AppPageTransitions.kinds` lists every path in `AppRoutes.all` (a test asserts the sets are equal, so a new route cannot fall back silently): shared-axis X for the steps of a flow (onboarding, login, sign-up, OTP, biometrics, password reset, transfer → review), shared-axis Y for the add-card form (it rises like a sheet), shared-axis Z for drill-in lists pushed over home (history, notifications), fade-through for root switches and results (welcome, the tab shell and its four branch roots, card details behind the Hero, payment success, gallery). `/cards/<id>` matches the pattern entry by prefix. The F1 `fade` fallback uses `FpMotion.standard` and `FpMotion.standardDecelerate` instead of literals.
- `app_router_test.dart` navigates through one route of each kind and asserts the `SharedAxisTransition` type / `FadeThroughTransition` on screen.

### D-074: The "transfer review without a typed draft" case
- Reported flaky once in F3, when the success screen still used real-time `Future.delayed` entrance timers (legacy widgets, deleted in F5). In Wave 2 it passed 10/10 isolated runs and every full-suite run, so the original cause is gone. The remaining non-determinism in that file was that `FinPayApp` dispatches four database loads to the sqflite ffi worker thread while the test only advances fake time: under host load a load could complete after `di.reset()` closed the blocs. The test now flushes real time (`runAsync` rounds) after the first frame and before tear-down, so the outcome no longer depends on scheduling. No test was weakened or skipped.

### D-075: Integration tests boot the app without `main()`
- `integration_test/flows.dart` runs `di.init()`, `ensureDemoAccount`, settings and session restore itself, then pumps `FinPayApp()`. Calling `main()` would also invoke the native splash and orientation plugins (fine on a device, not needed by the test) and would re-register GetIt on the second test. Each test starts with `di.reset()`.
- Every flow is device-state independent: `reachLogin` logs out a restored session through the profile tab, walks the welcome screen (first run or "seen") and the three onboarding pages, and ends on the login form. Finders are the existing `ValueKey`s; no keys had to be added.
- `app_flows_test.dart` wraps swipe-to-pay in `binding.traceAction` and the card stack in `binding.watchPerformance`; `perf_test.dart` traces six screens for `flutter drive --profile`; `test_driver/integration_test.dart` turns every `*_timeline` report into `build/perf/<name>.timeline_summary.json` (plus the raw timeline) and every `*_performance` report into `build/perf/<name>.performance.json`.
- No device was attached while Wave 2 ran (`adb devices` empty), so the files are compiled and analysed but their results are "not run: no device" (README, LOAD_TEST_REPORT). The commands are documented for the owner.

### D-076: The widget gallery is the router's default, debug-only
- `AppRouter.build` registers `FpGalleryScreen` for `/gallery` unless a test overrides it; `app.dart` no longer needs to know about it. The redirect still sends release builds to home/login and the screen renders nothing in release, so the profile "Widget gallery" row works in debug and is inert in release.

### D-077: Host frame benchmark per key screen, one table
- `test/stress/screen_frames_stress_test.dart` measures the five key screens the same way (build + layout + paint of one `pump` on the host) and prints one Markdown table; LOAD_TEST_REPORT "Wave 2: consolidated run" copies it. Device raster numbers come from `perf_test.dart` when a device is attached.

### D-078: Coverage table from lcov without `lcov`
- `tool/coverage_summary.dart` folds `coverage/lcov.info` (LF/LH only, so it matches `lcov --summary`) per top-level `lib/` folder into the Markdown table used in README and LOAD_TEST_REPORT; `coverage/` stays ignored.

### D-079: Screenshots are copies of goldens
- `docs/images/` holds the gallery, tokens and buttons goldens (1.0×) as the spec's "screenshot of the gallery", plus a README listing the ten flows to record on a phone (motion does not survive a golden). The 1.3× gallery golden is not copied (1.4 MB; the test folder keeps it).

### D-080: Tests switch off sqflite's lock-warning timer
- Every sqflite query that waits for the database lock arms a 10 s `Timer` ("database has been locked for 10 seconds") under the widget test's fake clock. On a slow runner the test can finish before the real-thread query returns and the still-armed timer fails it with "A Timer is still pending even after the widget tree was disposed" (CI run for a9aee63, `app_shell_test`; the next run passed unchanged). `test/flutter_test_config.dart` now sets `lockWarningDuration = null`, which stops the timer from being created at all, instead of each harness pumping 11 s of fake time. The setter is deprecated ("used internally") and `setLockWarningInfo` cannot clear it, so the single use carries an `ignore` with the reason. The warning is a development aid for deadlocks; production code is untouched.

### D-081: Integration flows are written for real devices, including ones with animations off
- The first run on a phone (moto g64 5G, Android 15) found four things the host could not: (1) go_router builds the next page a frame later, so a flow must wait for the destination screen type, not `pump()` once; (2) the contact picker is a lazy horizontal list, so an off-screen contact has no element until `dragUntilVisible` scrolls to it; (3) with the developer option "animator duration scale" at 0 Flutter reports `disableAnimations`, the app honours reduce motion and `FpSwipeToPay` renders its confirm button, so `swipeToPay` accepts either the thumb or the button; (4) `traceAction`/`watchPerformance` need the VM service, which DDS owns under `flutter test`, so the flows wrap them in `traced`/`watched` helpers that fall back to running the section uninstrumented (the library throws before the action runs, so nothing runs twice) and every documented `flutter drive` command carries `--no-dds`. The pile gained a `cards-pile` key because its semantics label changes with the card count. The three flows pass on the phone in 35 s.
- The profile-mode `flutter drive` run then found four more: (5) `IntegrationTestWidgetsFlutterBinding.registerTestTextInput` is false, so `enterText` sends client id -1, which `TextInput` accepts only inside an `assert` — typing works in debug and is silently dropped in profile; `launchApp` now calls `testTextInput.register()`, which also keeps the real IME out of the run; (6) a root-navigator page (success, failure) sits above the shell, so `find.byType(AppShell)` matches before the page is gone — `backHome` waits for the page to leave the tree; (7) the tool reinstalls the app when switching debug/profile builds, which wipes the database, so the card-stack section seeds two Luhn-valid cards (`freshTestPan`) when the stack is empty, and the driver skips a timeline with no frames instead of throwing; (8) the first tap after a tab switch can be dropped under the live frame policy, so `addDemoCard` retries the Add tap until the page is up. The six sections then trace end to end on the moto g64 (D-082 records the numbers).

### D-082: Device numbers rank raster, not build, as the next performance target
- Profile traces on the moto g64 5G (60 Hz panel; table in `docs/LOAD_TEST_REPORT.md` "Device raster numbers") show build averages of 1–5 ms with no missed build frames on four of six sections, while raster averages 6–11 ms and the card fan-out (19/195), statistics (17/183) and swipe-to-pay success (11/192) miss the 16 ms raster budget on 6–10 % of frames. The keypad's build p90 of 16 ms is the one build-side outlier. Decided follow-ups, in order: fewer NeoPOP shadow layers while cards are in motion, a `RepaintBoundary` around the chart area, a smaller confetti burst on 60 Hz panels, a narrower rebuild scope on the keypad. Not done here: each is a visual change that needs new goldens and a device re-run, so they are recorded as the next feature rather than squeezed in.

## Compromises

### F7 / Wave 2
- No device was attached (`adb devices` empty), so the integration flows and the profile traces are written, analysed and documented but not executed; every device number reads "not run: no device".
- The host frame numbers are build/layout/paint on a Linux JIT with software rendering; they rank screens relative to each other and catch regressions, they do not predict a phone's raster time.
- The Android `styles.xml` hand edits (D-071) must be re-checked after any `flutter_native_splash:create` run; the generator rewrites `LaunchTheme`.
- `flutter_native_splash` is a runtime dependency (D-070); `flutter_launcher_icons` stays dev-only.
- Files touched outside `integration_test/`, `test_driver/`, `tool/`, docs and tests: `lib/app.dart` (theme, no gallery wiring), `lib/main.dart` (splash), `lib/routes/app_router.dart` (gallery default), `lib/routes/app_page_transitions.dart` (map), five deleted legacy files (D-072), `pubspec.yaml`/`pubspec.lock`, `android/app/src/main/res/**`, `ios/**` (generated icons/splash), desktop plugin registrants (packages removed). All additive except the deletions, which had zero users.

### F6
- Paging is limit/offset (D-061); keyset paging stays a recommendation for ledgers past the F1 breaking point (400k rows). Search results are capped at 50 and not paged.
- One swipe row open at a time is not enforced (D-065); opening a second row leaves the first open until tapped.
- The bar chart has the deterministic tooltip; the line chart uses `fl_chart`'s built-in tooltip; the donut has none (legend instead).
- Goldens with clock text are zone-independent because the fixture "now" is a *local* noon; the suite passes in IST (author) and UTC (CI).
- Stress: scrolling 50 pages of a 10k-row ledger on the host averages 13 ms/frame with 86/300 frames over 16 ms (each measured frame also lays out the rows a 600 px drag reveals under the Dart JIT); the 100k-row run averaged 9.3 ms. Verify on the moto g64 in Wave 2. RSS grew 372 → 407 MB over 1,000 dismiss + undo cycles with zero tickers or toasts left; the VM heap simply grew (GC is not forced in tests).
- The "Biometric sign-in" toggle flips the preference only (F3 compromise: biometric unlock is not wired to a keystore-held secret); it does not check hardware availability.
- Files touched outside the four screen folders and the new design-system files: `lib/data/datasources/local_datasource.dart` + `sqflite_local_datasource.dart` (type filter, bounds, `markNotificationsRead`), `lib/domain/repositories/transaction_repository.dart` + `notification_repository.dart` and their impls (additive methods/params), `lib/blocs/notification/*` (two events, de-dup add), `lib/core/di/injection_container.dart` (`notificationRepository` override), `lib/screens/shell/app_shell.dart` (`protectedTabs` gains Stats), `lib/screens/auth/widgets/spring_rise.dart` (D-069), `lib/design_system/components/fp_toast.dart` (action) + `design_system.dart` + `gallery_screen.dart` (section), `pubspec.yaml`/`pubspec.lock` (`fl_chart` added; `shimmer`, `flutter_staggered_animations` removed), `docs/DESIGN_SYSTEM.md`, and tests: `screen_harness.dart` (override + 5 s dispose pump), `home_cards_fixtures.dart` (date-range stub), `app_shell_test.dart` (Stats protected, longer flush), `payment_cubit_test.dart` (`FakeLedger` new methods), `notification_bloc_test.dart`, `transaction_notification_repository_test.dart`, `sqflite_local_datasource_test.dart`, `gallery_test.dart`, `design_system_golden_test.dart` (new DS golden; gallery goldens regenerated).

### F5
- The note is not persisted (no ledger column; D-058); "Share receipt" copies text instead of opening the system share sheet (D-055).
- The amount display always shows two decimals while typing (D-053).
- "Insufficient balance" is not reachable from the demo data without a stale balance or a crafted extra (D-050/D-052); the other three outcomes are.
- The simulated bank's "first settlement times out" memory is per process (D-057).
- While dragging, the slider label sits partly under the thumb (it fades out over the first 40 %); a clipped label would cost a `saveLayer`.
- Stress: 12 of 10,000 keypad frames exceeded 16 ms on the host (JIT/GC noise, see LOAD_TEST_REPORT); no fix applied.
- Files touched outside `lib/screens/transfer` and the new design-system files: `lib/domain/payments/payment_gateway.dart`, `lib/domain/contacts/contact.dart`, `lib/domain/repositories/contact_repository.dart`, `lib/data/repositories/demo_contact_repository.dart`, `lib/core/platform/fakes/fake_payment_gateway.dart` + `fakes.dart` (new), `lib/core/di/injection_container.dart` (two overrides + two registrations), `lib/routes/app_router.dart` (`initialExtra`, success route takes `PaymentReceipt`), `lib/blocs/notification/notification_bloc.dart` and `lib/blocs/transaction/transaction_bloc.dart` (D-059), `lib/design_system/gallery/gallery_screen.dart` (section), `pubspec.yaml` (`confetti` removed), `test/widget/screens/screen_harness.dart` (`extra`, two overrides), `test/widget/app_router_test.dart` (success route expects a receipt), `test/design_system/gallery/gallery_test.dart` and `test/golden/design_system/design_system_golden_test.dart` (new section; gallery goldens regenerated). All additive except the success-route extra type (D-051).

### F4
- `TransactionBloc` (F1) loads the whole ledger for `LoadTransactionsEvent`; home shows five rows but still pays for the full read (10k rows: home ready in 102 ms on the host). F6 should page (keyset, LOAD_TEST_REPORT F1 recommendation) or add a `limit` for the home tab.
- Freeze is session-local and "recent card payments" are all `payment` rows (D-047).
- The tapjacking hook (`window.decorView.filterTouchesWhenObscured = true` in `MainActivity.onResume`) could not be compiled here (no Gradle on this machine); it is two lines of standard Android API, but the first device build should confirm it.
- The tab-visible check and the sensor subscription depend on the shell's inherited index; outside the shell (a tab screen pumped alone) everything counts as visible.
- The widget tests for the legacy statistics/profile tabs still need `ScreenHarness.flush` after a tab switch because those screens call `setState` after an awaited database read (UI audit 2.15/2.17); Agent F's rewrite removes the need.
- Files touched outside `lib/screens/home`, `lib/screens/cards`, `lib/screens/shell` and `lib/design_system`: `routes/app_routes.dart`, `routes/app_redirect.dart`, `routes/app_router.dart`, `routes/app_page_transitions.dart` (new paths, shell, prefix guard), `screens/auth/widgets/secure_screen.dart` (`active` flag), `blocs/card/card_bloc.dart` (`maskSensitive`), `domain/repositories/card_repository.dart` + `data/repositories/card_repository_impl.dart` (`readCvv`), `core/di/injection_container.dart` (repository overrides, `maskSensitive: true`), `screens/statistics/statistics_screen.dart` and `screens/profile/profile_screen.dart` (bar and back arrow removed only), `android/.../MainActivity.kt` (tapjacking), `test/widget/screens/screen_harness.dart` (overrides), `test/unit/blocs/card_bloc_test.dart`, `test/unit/data/repositories/card_repository_test.dart`, `test/unit/routes/app_redirect_test.dart` (added cases), `test/design_system/gallery/gallery_test.dart` and `test/golden/design_system/design_system_golden_test.dart` (new sections). All additive.

### F3
- Phone-based OTP is simulated (D-030) and the reset email is never sent; both are stated on screen as "Demo build".
- Biometric unlock is enrolled and persisted (`biometricEnabled`) but not yet used to sign in: the credential check needs the password hash, so a biometric-gated sign-in would need a stored secret behind the keystore (Wave 2 / profile settings).
- Sign-up re-keys the device's single account (D-031) rather than creating a second user.
- `AppSettings`, `SettingsCubit`, `SharedPreferencesSettingsRepository`, `AppRedirect`, `AppRouter`, `AppPageTransitions` and one line of `app.dart` (passing the settings cubit to the router) were touched outside the screen folders; all additive.
- Legacy-widget deletion: only `cred_page_transition.dart` reached zero usages; the other files in the pending table are still imported by the home/cards/transfer/insights screens (Agents D–F).
- The DB-backed sign-up completion runs real sqflite I/O inside widget tests; the harness has a `flush()` helper (`tester.runAsync`) for the two tests that need the write to finish.

### F2
- Material icons are not loaded in golden tests, so icons render as boxes in the baselines (D-009). Loading `MaterialIcons-Regular.otf` from the SDK cache is possible in Wave 2 if real icon glyphs are wanted.
- `FpButton(expand: true)` needs a bounded width (wrap in `Expanded` inside a `Row`), like any full-width Material button.
- The flip card, custom pull-to-refresh, swipe-action row and bottom navigation named in the audit are not part of F2; they belong to the Wave 1 features that own their screens (F4, F6, F7) and are listed under "Pending removals".
- Load numbers are build/layout times on the Linux test host, not device raster times (Wave 2).

