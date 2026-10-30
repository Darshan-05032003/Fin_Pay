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

## Compromises
_None yet._
