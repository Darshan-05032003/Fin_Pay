# Load / performance report

One entry per feature (spec §7b). Stress tests live in `test/stress/`, tag
`stress`, and only run with:

```
flutter test --tags stress --dart-define=FINPAY_STRESS=true --concurrency=1 test/stress
```

Machine for the numbers below: the build box (Linux, Dart VM JIT, sqflite through `sqflite_common_ffi` on a temp file). Phone numbers will be slower; the shape (what is O(1), what grows) is what matters.

## Feature: F1 Foundations
- Scenario and scale:
  - `test/stress/foundations_stress_test.dart`, 7 scenarios:
    1. 100,000 transactions inserted through `SqfliteLocalDataSource.saveTransactions` in batches of 5,000, then paging, search (title and recipient `LIKE`), a one-day date range, daily group-by totals (all days and the last 30), a full 100k scan and one duplicate check.
    2. 100,000 v1 rows (REAL rupees, `TransactionType.x` strings) migrated to v2 by `AppDatabase`.
    3. 1,000 sequential `AddTransactionEvent`s through `TransactionBloc` against the real data source, every `idempotencyKey` submitted twice; tracked resources: the state's row count (limit 5), the effects-stream listener flag, RSS.
    4. Breaking point: rows grown 10k → 50k → 100k → 200k → 400k, timing first page, last page (offset), search and daily totals at each step.
    5. `Money.parse`/`format` throughput, 200k each.
    6. PBKDF2 verify cost at the production 10,000 iterations.
    7. Dates: a DST-gap local time stored and read back as the same UTC instant with an injected `Clock`.
- Results (numbers):
  - 100k insert: **1,472 ms** (≈68k rows/s). First page of 50: **2 ms**. Page at offset 50,000: **22 ms**. Title search: **12 ms**; recipient search: **1 ms**. One-day range (1,440 rows): **8 ms**. Daily totals, all 70 days: **30 ms**; last 30 days: **15 ms** (24 ms before the fix below). Full 100k scan into models: **338 ms**. Duplicate check: **1 ms**.
  - Migration of 100k v1 rows: **313 ms** (seeding the v1 database itself: 978 ms).
  - 1,000 BLoC adds: **1,272 ms total, 1.27 ms per event**; exactly 500 rows written and 500 `TransactionDuplicate` effects; balance debited exactly 500 × ₹1.00; state stayed at 5 rows; RSS 320 MB → 201 MB (GC ran; no growth). The earlier run showed +55 MB, which the second run gave back, so there is no monotonic growth.
  - Breaking point (ms): 

    | rows | page 50 | last page (offset) | search | totals all | totals 30d |
    |---|---|---|---|---|---|
    | 10k | 0 | 4 | 1 | 1 | 2 |
    | 50k | 0 | 19 | 11 | 10 | 13 |
    | 100k | 0 | 40 | 22 | 25 | 14 |
    | 200k | 0 | 86 | 45 | 57 | 15 |
    | 400k | 0 | 179 | 93 | 104 | 16 |

    First query over 100 ms: offset paging to the last page at **400k rows** (179 ms) and the all-days group-by at **400k rows** (104 ms). Title search stays under 100 ms up to 400k. First-page and 30-day totals are flat.
  - `Money.parse`: **2.8 µs** each (558 ms / 200k); `Money.format`: **0.7 µs** each.
  - PBKDF2 verify (10k iterations): **27 ms** per attempt in the JIT VM.
- What broke:
  - `getDailyTotals(limitDays: 30)` grouped every row and only then applied `LIMIT`, so it cost as much as the full group-by (77 ms at 400k) and grew linearly with history.
  - Offset-based paging grows linearly with the offset (179 ms for the last page of 400k rows); a user scrolling to the bottom of years of history would feel it.
  - Nothing else broke: no duplicate rows, no balance drift, no overflow, no leaked listeners.
- Failure flow (step by step):
  1. Statistics screen asks for the last 30 days of totals.
  2. SQLite walks the whole `transactions` table building `substr(date,1,10)` groups (no index can help a function on the column).
  3. It sorts all groups and discards all but 30. Time ∝ total rows, not ∝ 30 days.
- Fix applied / recommendation:
  - Fixed: `getDailyTotals(limitDays:)` now reads `MAX(date)`, derives the lower bound and filters `WHERE date >= ?` before grouping, so the date index bounds the scan. 400k rows: 77 ms → **16 ms**, flat across sizes (unit-tested in `sqflite_local_datasource_test.dart`).
  - Recommendation (F6, transactions list): page with a keyset (`WHERE date < ? ORDER BY date DESC LIMIT 50`, using the last row's date/id) instead of `OFFSET`; every page is then the 2 ms first-page cost. `getTransactionsBetween` already provides the index-friendly shape.
  - Recommendation: keep the full-history group-by for the statistics "all time" view only, or cache per-month totals once F6 adds charts.

Numbers below are from the test runner (Flutter 3.47.9, Linux x86-64 host,
software rendering, ~1.4 GiB free RAM). They measure widget build + layout time
per pumped frame, not GPU raster time; on-device profile traces are Wave 2.

## Feature: F2 Design system
- Scenario and scale:
  1. 1,000 rapid taps on an `FpButton` with a synchronous `onPressed`.
  2. `ListView.builder` of 10,000 tappable `FpSurface` rows (text + numeric
     amount each), five flings at 6,000 px/s, 60 frames measured per fling.
  3. `FpAmountText` rolled from ₹0.00 to ₹99,99,99,999.99 and back, 100 times.
  4. `FpConfetti`: 50 bursts of 80 particles, 10 frames pumped per burst.
  5. 50 `FpSkeletonRow`s (200 shimmer blocks) inside one `FpSkeletonGroup`,
     120 frames.
- Results (numbers):
  1. 1,000 taps dispatched in 294 ms; `onPressed` called **1** time.
  2. 300 frames: avg **2.07 ms**, p90 **3.25 ms**, p99 **5.49 ms**, frames
     over 16 ms: **0**. No exceptions; rows stay interactive.
  3. 100 rolls (up to 16 columns each) in 628 ms; active tickers after:
     **0** (no leaked controllers).
  4. 500 frames in 77 ms; tickers after: **0**; 50 bursts recorded.
  5. 120 frames in 291 ms (**2.42 ms/frame**) with **1** active ticker for
     all 200 blocks.
- What broke:
  - Nothing failed at these scales. The one measurable risk found during
    development: the first skeleton draft gave every block its own
    `AnimationController`; 200 blocks would have meant 200 tickers per
    frame. `FpSkeletonGroup` shares one.
  - The `shimmer` package (used by the old `SkeletonLoader`) wraps each block
    in a `ShaderMask` (a `saveLayer` per block); the gradient-only shimmer
    avoids that (D-007).
- Failure flow (step by step): none reached. The breaking point for the
  odometer is width: at 1.3× text scale ₹99,99,99,999.99 in `displayMedium`
  is about 390 px wide, so screens must give it the full width or use
  `displaySmall` (the golden test covers 1.3×).
- Fix applied / recommendation:
  - Shared shimmer ticker; gradient instead of `ShaderMask`.
  - `FpAmountText` uses one controller for all columns and tabular cells, so
    width never jitters and there is nothing per digit to dispose.
  - Keep `FpSurface` rows under `itemExtent` lists; the painter draws edges
    outside its box, so the reserved padding (`depth`) keeps rows from
    overlapping (already built in).
  - Wave 2: repeat scenario 2 on a mid-range device with
    `flutter drive --profile` and record raster times.

## Feature: F3 Onboarding + Auth
- Scenario and scale:
  - `test/stress/auth_stress_test.dart`, 7 scenarios:
    1. 1,000 rapid taps on the real login screen's "Sign in" with the
       repository gated on a `Completer`.
    2. 10,000 random OTP inputs (junk, emoji, bidi, NUL, non-ASCII digits,
       backspace/verify/resend interleaved) through the pure `OtpMachine`.
    3. 2,000 junk pastes through the real `FpOtpField` widget.
    4. 1,000 login failures through `LoginCubit` → `SessionCubit` →
       `AuthRepositoryImpl` (real PBKDF2, `FakeSecureStorage`, fake clock),
       letting the 30 s lock expire every 50 attempts; RSS before/after.
    5. 1,000 wrong passwords straight at the repository (does hashing stop
       once locked?).
    6. 500 onboarding page flings (3,000 pumped frames) with frame build
       times, then a ticker count after dispose.
    7. 5,000 hostile edits of the login fields through `bloc_test`.
- Results (numbers, Linux test host, Dart JIT):
  - 1,000 login taps dispatched in **485 ms** → **1** `signIn` call; the app
    landed on `/home` once the gate opened.
  - 10k OTP machine transitions: **34 ms**; max digits **6**; never threw.
  - 2,000 `FpOtpField` pastes: **4,199 ms** (2.1 ms per paste including the
    text-input round trip); max digits **6**; no exception.
  - 1,000 login failures: **2,586 ms**; **80** hashed `InvalidCredentials`
    (4 before each of 20 locks), **920** answered from the lock record without
    hashing; RSS **231 MB → 236 MB** (no growth beyond GC noise); the form
    re-enabled after the last expiry.
  - 1,000 repository sign-ins with a stored credential: **14 ms**; **996**
    `AccountLocked` responses (hashing stops after the fifth failure, so a
    brute force costs the attacker time, not the device CPU).
  - 500 onboarding swings: **6,129 ms**, 3,000 frames, build **avg 0.63 ms,
    p90 0.79 ms, p99 1.77 ms**; **0** tickers after dispose.
  - 5,000 hostile edits: state stayed `idle`, no exception.
- What broke:
  - The first draft of scenario 4 closed the cubit on the 50th attempt and
    then measured nothing (a test bug, not a product one); and with no stored
    credential for the address the repository never hashed (unknown e-mail
    and wrong password are indistinguishable by design), so the "cost" line
    was meaningless until a credential was seeded.
  - Nothing in the product broke at these scales.
- Failure flow (step by step): none reached. The expensive path is one
  PBKDF2 verify (~27 ms JIT) per *unlocked* wrong attempt; the lock record
  makes attempts 5–∞ of each 30 s window free.
- Fix applied / recommendation:
  - Stress test rewritten on `fake_async` with a seeded credential.
  - Keep the OTP and lock countdowns on the injected `Clock` (D-033) so a
    stuck or jumping clock cannot pin a user.
  - Wave 2: repeat scenario 6 on a device in profile mode for raster times;
    the illustrations are three `CustomPaint`s per page under one
    `RepaintBoundary`, so raster cost should be flat.
