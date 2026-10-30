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

