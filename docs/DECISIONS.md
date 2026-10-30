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

## Compromises

### F2
- Material icons are not loaded in golden tests, so icons render as boxes in the baselines (D-009). Loading `MaterialIcons-Regular.otf` from the SDK cache is possible in Wave 2 if real icon glyphs are wanted.
- `FpButton(expand: true)` needs a bounded width (wrap in `Expanded` inside a `Row`), like any full-width Material button.
- The flip card, custom pull-to-refresh, swipe-action row and bottom navigation named in the audit are not part of F2; they belong to the Wave 1 features that own their screens (F4, F6, F7) and are listed under "Pending removals".
- Load numbers are build/layout times on the Linux test host, not device raster times (Wave 2).

