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

## Compromises

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

