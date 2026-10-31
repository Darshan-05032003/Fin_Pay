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

## Feature: F4 Home + Cards
- Scenario and scale:
  - `test/stress/home_cards_stress_test.dart`, 5 scenarios on the real router + DI harness:
    1. 50 cards in the stack, fanned, with a fake accelerometer sample every frame (60 Hz) for 300 frames, then 20 flips of the front card under tilt (30 frames each), then 10 swipes across the carousel under tilt (20 frames each); frame build times; tickers and sensor subscriptions after dispose.
    2. 10,000 transactions inserted in the in-memory sqflite database (batches of 2,500), then the home tab opened: time until the balance is on screen, number of rows rendered, RSS.
    3. 1,000 rapid taps on the hide-balance eye: final state, persisted state, number of settings writes.
    4. 1,000 rapid taps on "Add card" with the repository gated on a `Completer`: rows stored, where the app lands.
    5. Home at 1.3× text scale with a balance of ₹99,99,99,999.99: 60 frames of the odometer count-up, final label, tickers after dispose.
- Results (numbers, Linux test host, Dart JIT, software rendering):
  1. 50-card stack under 60 Hz tilt: 300 frames, **avg 1.23 ms, p90 1.60 ms, p99 2.45 ms**, frames > 16 ms: 0. 20 flips under tilt: 600 frames, avg 1.09 ms, p90 1.47 ms, p99 4.97 ms, > 16 ms: 0. 10 swipes under tilt: 200 frames, avg 1.46 ms, p90 1.69 ms, p99 10.51 ms, > 16 ms: 0. Tickers after dispose: **0**; sensor listeners: **0**.
  2. 10k transactions: seed **188 ms**; home ready **102 ms** after the route is pumped (includes the full-ledger read, see below); rows on screen: **5**; RSS 324 MB (test process, includes the compiler).
  3. 1,000 hide-balance taps dispatched in **400 ms**: final hidden = false (even count), persisted = false, writes = **1,000** (one per change, none coalesced away, none duplicated).
  4. 1,000 add-card taps dispatched in **299 ms**: stored = **1**, the app returned to `/cards`.
  5. Odometer to ₹99,99,99,999.99 at 1.3×: 60 frames, avg 1.20 ms, p90 2.45 ms, p99 6.27 ms, > 16 ms: 0; label `Available balance ₹9,99,99,999.99`; tickers after dispose: 0.
- What broke:
  - Nothing in the product failed at these scales. Two drafts were fixed before the numbers above: the fan-out spring settled at 0.9999 so the carousel never swapped in (snap on completion), and a detached `MotionSensor` subscription survived a tab switch because the visible-tab check was not an inherited dependency (the shell now publishes the index through an `InheritedWidget`).
  - Observation, not a failure: `LoadTransactionsEvent` reads the whole ledger (F1 design); with 10k rows that is ~35 ms of the 102 ms. Home only needs five rows.
- Failure flow (step by step): none reached. The expensive path in the stack is the pile with many cards: only the top four are drawn (`CardStackMath.maxPileDepth`), so 50 cards cost the same as 4; the carousel builds pages lazily. The odometer's cost is width, not digits (D-016 / F2 report): at 1.3× the header fits ₹99,99,99,999.99 through a `FittedBox`.
- Fix applied / recommendation:
  - Only the visible tab subscribes to the accelerometer; the stream is cancelled on tab change and dispose; samples are damped (D-046).
  - The pile draws at most four cards; neighbours in the carousel are plain art (no tilt, no flip controllers) so tickers scale with 1, not with the card count.
  - Recommendation (F6/F7): page the ledger or give home a `limit`, so the 5-row list does not depend on the ledger size (F1 report already recommends keyset paging).
  - Wave 2: repeat scenario 1 on a mid-range device in profile mode for raster times; the card art is one `CustomPaint` per card under a `RepaintBoundary`, and the sheen is a gradient `DecoratedBox` (no `saveLayer`), so raster cost should be flat.

## Feature: F5 Payments
- Scenario and scale:
  - `test/stress/payments_stress_test.dart`, 5 scenarios:
    1. Review screen on the real router + DI harness with the bank gated: a two-finger drag past the threshold, then 1,000 alternating full swipes and taps on the slider (1,002 gestures); gateway and ledger calls counted after release.
    2. 1,000 sequential `PaymentCubit` payments through the real `TransactionBloc` into an in-memory sqflite ledger (`SimulatedPaymentGateway` with zero latency); every tenth payee is `@flaky` (timeout, then Retry on the same key); rows, balance, "already paid" count, effect listeners and RSS checked.
    3. 10,000 keypad inputs on the transfer screen (13-key cycle of digits, point and backspace), one 16 ms frame per input; frame build times.
    4. Success screen: 100 frames of the confetti burst and the amount odometer; tickers after the burst.
    5. 50 contacts in the picker: 60 frames of the staggered entrance, then a search filter.
- Results (numbers, Linux test host, Dart JIT, software rendering):
  1. Slider: 1,002 gestures dispatched in **454 ms** → **1** authorize call, **1** ledger write, the app landed on `/transfer-success`.
  2. 1,000 payments (100 flaky retries) in **1,920 ms** (≈1.9 ms per payment including two bank phases and the exclusive ledger transaction): rows **1,000**, already paid **100**, balance exact (₹1,00,00,00,000 − ₹5,995.00), effect listeners after **0**, RSS **301 → 307 MB**.
  3. Keypad: 10,000 inputs in **27.1 s** (test-harness tap + frame cost); 10,000 frames, **avg 1.94 ms, p90 4.89 ms, p99 8.29 ms**, frames > 16 ms: **12** (0.12 %, JIT/GC pauses on the host); the final amount is a valid odometer value.
  4. Confetti + odometer: 100 frames, **avg 0.15 ms, p90 0.27 ms, p99 0.97 ms**, > 16 ms: 0; tickers after the burst: **0**.
  5. 50-contact entrance: 60 frames, **avg 0.21 ms, p90 0.42 ms, p99 2.30 ms**, > 16 ms: 0; search filter (type + rebuild) **49 ms** for the first keystroke (includes `enterText`).
- What broke:
  - Scenario 3 crashed the first transfer-screen draft: the inline error's keyed `AnimatedSwitcher` collided with itself when the error flipped faster than its 150 ms transition ("Duplicate keys found"). Fixed with a single `Text` under `AnimatedDefaultTextStyle` (SECURITY_REVIEW F5, Low).
  - Nothing else failed. The `@flaky` retries exercised the duplicate path 100 times with exactly one row each.
- Failure flow (step by step): none reached in the product. The expensive path per payment is the ledger's exclusive transaction (user read, key lookup, insert, balance update); at ~1.9 ms per payment on the host the bank latency (2 × 900 ms simulated) dominates on a device, not the app.
- Fix applied / recommendation:
  - The slider, the cubit and the ledger each refuse a second confirmation (guard → in-flight flag → unique key), so the 1,000-gesture burst costs one bank round trip.
  - `PaymentCubit` listens to the effects stream only between dispatch and answer and cancels synchronously, so 1,000 payments leave no listener.
  - Recommendation: the keypad's >16 ms frames are host JIT noise; verify on the moto g64 in profile mode in Wave 2 (`FpAmountText` is one `RepaintBoundary`, the keypad another). If the ledger ever grows past the F1 breaking point (400k rows, OFFSET paging), the review is unaffected (one key lookup by index), but `TransferCubit.load` reads 20 recent rows and would inherit the F6 paging work.

## Feature: F6 Insights + Activity
- Scenario and scale:
  - `test/stress/insights_activity_stress_test.dart`, 6 scenarios:
    1. 10,000-row and 100,000-row ledgers seeded into the real in-memory sqflite database (batches of 5,000): first page through `TransactionsCubit`, the page at the last offset, the real `/transactions` screen scrolled 50 pages (6 × 600 px drags per page, each followed by a flush so the next page can arrive), then four searches over the whole ledger (`Priya`, `Coffee 9`, `zzz`, `' OR 1=1 --`).
    2. 2,000 rapid `SettingsCubit` flips (1,000 × haptics set + hide-balance toggle) on an in-memory repository: final state, repository state and write count.
    3. 1,000 swipe-dismiss + Undo cycles on the real notifications screen (mocked repository counting writes): rows, duplicates, open toast, transient callbacks (tickers), RSS.
    4. Statistics with four rows per day for a year (365 daily points, 12 monthly bars): 60 frames of the year entrance, then 10 Week ↔ Year switches × 30 frames.
    5. 500 notifications: 60 frames of the staggered entrance, 40 scroll frames, "Mark all read".
- Results (numbers, Linux test host, Dart JIT, software rendering):
  1. Seeding: 10k rows **229 ms**, 100k rows **1,005 ms**. First page: **3 ms** (10k), **0–1 ms** (100k). Page at the last offset: **3 ms** (10k), **30 ms** (100k, OFFSET 99,950). 50 pages scrolled: 10k rows **6.9 s** wall (test gestures + flushes), 1,950 rows loaded, 300 frames **avg 13.06 ms, p90 23.06 ms, p99 40.22 ms, > 16 ms: 86**; 100k rows **5.4 s**, 1,950 rows, 300 frames **avg 9.27 ms, p90 15.86 ms, p99 22.37 ms, > 16 ms: 29**; RSS 364 / 384 MB. Search over 100k rows: `Priya` 50 rows **0 ms** (early exit at the cap), `Coffee 9` **7 ms**, `zzz` **7 ms**, injection string **7 ms**, 0 rows each; over 10k rows 1–3 ms.
  2. 2,000 flips in **25 ms**, **1,999 writes** (the first flip set haptics to its current value and the cubit skipped it), final state `hapticsEnabled: false, hideBalance: false`, repository equal to the cubit.
  3. 1,000 dismiss + undo cycles in **12.4 s** (1,000 deletes, 1,000 re-adds counted on the mock): 8 rows, 8 distinct ids, toast open **false**, transient callbacks **0**, RSS **372 → 407 MB**.
  4. Year chart entrance: 60 frames **avg 2.20 ms, p90 3.92 ms, p99 37.28 ms, > 16 ms: 1** (the first frame builds three `fl_chart` charts); 10 period switches: 300 frames **avg 2.05 ms, p90 2.48 ms, p99 15.67 ms, > 16 ms: 1**.
  5. 500 notifications entrance: 60 frames **avg 0.94 ms, p90 1.12 ms, p99 2.79 ms, > 16 ms: 0**; 40 scroll frames **avg 11.89 ms, p90 13.75 ms, p99 23.33 ms, > 16 ms: 1**; mark all read: **250 ids in one write, 34 ms** end to end.
- What broke:
  - Scenario 3 first left **3 transient callbacks** after 1,000 cycles and re-ran the entrance of every row on each dismiss: `ListView.separated` matched children by index, so inserting or removing a row re-created every other row's element (`FpEntrance` and the unread `FpPulse` restarted). Fixed with `findItemIndexCallback` keyed by id on both the notifications list and the transactions `SliverList.separated`; tickers after the run are now 0 and the cycle time fell from 24.7 s to 12.4 s.
  - The first stress draft expected 2,000 settings writes; the cubit's "same value → no write" rule is correct and the expectation now documents it.
  - Nothing else failed: no duplicate ids after 1,000 undos, the offset bookkeeping produced 1,950 distinct rows over 50 pages, and every hostile search returned a result instead of an exception.
- Failure flow (step by step): none reached in the product. The expensive path is scrolling a page of newly built rows on the host JIT (each measured frame also lays out ~10 fresh `FpSwipeActionRow`s); on a phone the raster of the NeoPOP edges is the cost to watch (Wave 2).
- Fix applied / recommendation:
  - Keyed child reuse on both lists (above). Pages stay at 50 rows; `OFFSET` is 30 ms at 100k rows, so keyset paging remains a recommendation, not a need, for this ledger (D-061).
  - Search is capped at 50 rows and bounded to 200 characters (D-068); the title index makes the capped `Priya` search return in under a millisecond even at 100k rows.
  - The Stats tab loads only when first shown (D-066), so the start-up path pays no chart query.
  - Verify the 10k-row scroll frames on the moto g64 in profile mode in Wave 2; if the 16 ms budget is missed, cap the day groups' separators or move the row glyph to a `const` widget.

## Feature: F7 App-wide polish
- Scenario and scale: the F7 changes are a theme swap at the root, an explicit transition map, the gallery route, the native splash and five deleted legacy files; no new data path. `test/stress/screen_frames_stress_test.dart` (below) is the F7/Wave 2 benchmark; the splash hand-off adds one `preserve`/`remove` channel call pair at start-up.
- Results (numbers): start-up path unchanged in cost (DB open + settings + session restore run behind the splash as before); route transitions keep the F2 durations (450 ms forward, 400 ms reverse); the home collapse, cards fan-out, keypad, statistics and transactions scenarios are in the table below.
- What broke: nothing in F7. The first run of the new benchmark asserted "no tickers" while the transactions screen was still mounted (rows keep entrance/swipe tickers alive by design); the assertion now runs after the harness unmounts the tree, as in the F4/F6 stress tests.
- Failure flow (step by step): none reached.
- Fix applied / recommendation: `FpTheme.dark()` at the root removes a second `ThemeData` from the start-up path; keep `AppPageTransitions.kinds` exhaustive (tested) so no route ever pays for a mismatched transition.

## Wave 2: consolidated run

Command (Linux build box, Dart JIT, software rendering, `sqflite_common_ffi`; one file at a time):

```
flutter test --tags stress --dart-define=FINPAY_STRESS=true --concurrency=1 test/stress
```

Result: **41 tests, all green** (40 on the first pass + the transactions scenario after the assertion was moved behind the harness dispose; the file re-run is the frame table below). Wall time 1 min 46 s.

### Per-screen frame-time table (host)

Build + layout + paint of one `tester.pump` per frame on the host (no raster thread, no GPU). The numbers rank screens and catch regressions; a phone renders differently (the NeoPOP edges raster on the GPU, the JIT warm-up disappears in AOT). Source: `test/stress/screen_frames_stress_test.dart`.

| Screen / scenario | Frames | Avg | p90 | p99 | > 16 ms |
|---|---:|---:|---:|---:|---:|
| Home: header collapse + expand (10 cycles) | 300 | 2.56 ms | 4.57 ms | 7.56 ms | 0 |
| Cards: 12-card fan-out + collapse (5 cycles) | 375 | 1.59 ms | 1.92 ms | 7.15 ms | 1 |
| Transfer: 300 keypad inputs | 300 | 3.98 ms | 9.66 ms | 19.84 ms | 3 |
| Statistics: year entrance (365 points) + 4 switches | 180 | 2.09 ms | 3.14 ms | 16.14 ms | 2 |
| Transactions: 2,000 rows, 20 pages scrolled | 360 | 2.12 ms | 3.95 ms | 10.62 ms | 3 |

Reading: every screen averages 1.6–4.0 ms per frame; the outliers over 16 ms are the first frame after a layout change (the first keypad frame after the odometer gains a column, the `fl_chart` rebuild on a period switch, the first row build of a new page) and are JIT/GC noise on the host, as in F5/F6.

### Device raster numbers

Recorded on 2026-10-31 (after the Wave 2 merge) on a **moto g64 5G** (MediaTek MT6855 / Dimensity 7025, Android 15, 1080 × 2400 panel running at 60 Hz, so the 16.7 ms budget applies), Flutter 3.47.9, `flutter drive --profile --no-dds`, developer animation scales set to 1× for the run (this phone normally has them at 0, which the app honours as reduce motion) and restored afterwards. Six sections, one trace each, `TimelineSummary` 16 ms budget:

| Section (profile, moto g64 5G, 60 Hz) | Frames | Build avg / p90 / p99 | Build > 16 ms | Raster avg / p90 / p99 | Raster > 16 ms |
|---|---:|---|---:|---|---:|
| Home: header collapse + expand × 5 | 151 | 1.18 / 3.60 / 7.13 ms | 0 | 6.26 / 8.84 / 62.35 ms | 4 |
| Cards: seed two cards, fan out, swipe, collapse | 195 | 1.96 / 3.25 / 9.20 ms | 0 | 9.93 / 15.70 / 31.51 ms | 19 |
| Transfer: 7 keypad digits + 5 backspaces | 90 | 4.64 / 16.12 / 19.79 ms | 10 | 7.95 / 9.51 / 12.57 ms | 0 |
| Swipe to pay → processing → success (confetti) | 192 | 2.88 / 3.99 / 7.18 ms | 1 | 9.04 / 11.53 / 27.73 ms | 11 |
| Statistics: entrance + Month / Year / Week | 183 | 3.90 / 6.19 / 18.27 ms | 3 | 10.56 / 15.85 / 22.52 ms | 17 |
| Transactions: 6 flings | 265 | 0.96 / 1.40 / 1.62 ms | 0 | 5.77 / 7.26 / 7.78 ms | 0 |

Reading:
- Build time is not the problem on this phone: averages of 1–5 ms with zero missed build frames on four of six sections. The host table above ranked the screens the same way, so the host suite is a usable regression signal.
- **Raster is the heavy half.** Averages of 6–11 ms leave little headroom at 60 Hz, and the three motion-heavy sections miss the raster budget on 6–10 % of frames: card fan-out 19/195 (perspective-transformed NeoPOP cards with layered shadows), statistics 17/183 (`fl_chart` entrance and period switches), swipe-to-pay success 11/192 (confetti burst over the drawn check). The worst raster frames (48–64 ms) are single first-paint frames at a section's start.
- The keypad's build p90 of 16 ms (10 missed frames in 90) is the odometer column and keypad rebuilding per key press; raster stays under budget there.
- Transactions scrolling and the home header collapse are clean.

Follow-ups (D-082): fewer shadow layers while cards are in motion, a `RepaintBoundary` around the chart area, a smaller confetti burst on 60 Hz devices, and a narrower `setState` scope on the keypad. The integration flows (`app_flows_test.dart`, debug) pass on the same phone in ~35 s. Note that profile builds still print redacted `Logger` lines (release is silent by design).

To re-record:

```
flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/perf_test.dart --profile --no-dds -d <device id>
# → build/perf/{home_collapse,card_stack,transfer_keypad,swipe_to_pay,statistics,transactions_scroll}.timeline_summary.json
flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/app_flows_test.dart --no-dds -d <device id>
# → build/perf/swipe_to_pay.timeline_summary.json, build/perf/card_stack.performance.json
```

Each summary carries `average_frame_build_time_millis`, `90th_percentile_frame_build_time_millis`, `99th_percentile_frame_build_time_millis`, the raster equivalents and `missed_frame_build_budget_count` / `missed_frame_rasterizer_budget_count` per screen; the driver also prints one line per section.

### Full run output

Every number the suite printed on this run, in file order (`[stress]` / `STRESS` lines; the frame table above comes from the file re-run):

```
[stress] 1000 taps dispatched in 292 ms, onPressed calls: 1
[stress] 10k rows fling: 300 frames, avg 2.08 ms, p90 3.21 ms, p99 4.76 ms, frames > 16 ms: 0
[stress] odometer 100 rolls in 631 ms, tickers after: 0
[stress] 50 confetti bursts (500 frames) in 78 ms, tickers after: 0
[stress] 200 skeleton blocks, 120 frames in 279 ms (2.33 ms/frame), active tickers: 1
STRESS 100k-datasource insert_ms=1409 insert_rows_per_s=70972 page50_ms=2 page50_offset50k_ms=20 search_title_ms=11 search_recipient_ms=1 date_range_1day_ms=8 daily_totals_all_ms=30 daily_totals_30_ms=14 full_scan_100k_ms=336 duplicate_check_ms=2
STRESS 100k-migration seed_v1_ms=958 migrate_v1_to_v2_ms=330
STRESS 1000-bloc-adds total_ms=1751 per_event_ms=1.75 rows=500 rss_before_mb=323.8 rss_after_mb=382.1 rss_growth_mb=58.3
STRESS breaking-point 10000_page50_ms=0 10000_page50_last_ms=3 10000_search_ms=1 10000_daily_totals_all_ms=1 10000_daily_totals_30_ms=2 50000_page50_ms=0 50000_page50_last_ms=22 50000_search_ms=11 50000_daily_totals_all_ms=10 50000_daily_totals_30_ms=16 100000_page50_ms=0 100000_page50_last_ms=40 100000_search_ms=22 100000_daily_totals_all_ms=24 100000_daily_totals_30_ms=14 200000_page50_ms=0 200000_page50_last_ms=82 200000_search_ms=45 200000_daily_totals_all_ms=48 200000_daily_totals_30_ms=15 400000_page50_ms=0 400000_page50_last_ms=182 400000_search_ms=96 400000_daily_totals_all_ms=104 400000_daily_totals_30_ms=16 first_page_over_100ms_at_rows=400000 search_over_100ms_at_rows=none up to 400k daily_totals_over_100ms_at_rows=400000
STRESS money parse_200k_ms=549 format_200k_ms=136 parse_us_each=2.75 format_us_each=0.68
STRESS pbkdf2 verify_10k_iterations_ms=27.2
[stress] 1000 login taps dispatched in 464 ms, signIn calls: 1
[stress] 10k OTP machine inputs in 30 ms, max digits 6
[stress] 2000 FpOtpField pastes in 4150 ms, max digits 6
[stress] 1000 login failures in 2709 ms: invalid 80, locked 920, lock windows expired 20, RSS 386 MB → 389 MB
[stress] 1000 repository sign-ins in 14 ms, locked responses: 996 (hashing stops once locked)
[stress] 500 onboarding swings in 6028 ms, 3000 frames: avg 0.61 ms, p90 0.80 ms, p99 1.66 ms
[stress] tickers after dispose: 0
[stress] seeded 10000 rows in 229 ms
[stress] 10000 rows: first page in 3 ms
[stress] 10000 rows: page at offset 9950 in 3 ms
[stress] 10000 rows: 50 pages scrolled in 6951 ms, 1950 rows loaded (50 page waits): 300 frames, avg 13.29 ms, p90 23.90 ms, p99 40.92 ms, > 16 ms: 92; RSS 371 MB
[stress] 10000 rows: search "Priya" → 50 rows in 1 ms
[stress] 10000 rows: search "Coffee 9" → 0 rows in 1 ms
[stress] 10000 rows: search "zzz" → 0 rows in 1 ms
[stress] 10000 rows: search "' OR 1=1 --" → 0 rows in 1 ms
[stress] seeded 100000 rows in 1078 ms
[stress] 100000 rows: first page in 0 ms
[stress] 100000 rows: page at offset 99950 in 29 ms
[stress] 100000 rows: 50 pages scrolled in 5376 ms, 1950 rows loaded (50 page waits): 300 frames, avg 9.25 ms, p90 15.20 ms, p99 20.71 ms, > 16 ms: 25; RSS 388 MB
[stress] 100000 rows: search "Priya" → 50 rows in 0 ms
[stress] 100000 rows: search "Coffee 9" → 0 rows in 8 ms
[stress] 100000 rows: search "zzz" → 0 rows in 7 ms
[stress] 100000 rows: search "' OR 1=1 --" → 0 rows in 7 ms
[stress] 2,000 flips in 29 ms, 1999 writes
[stress] 1,000 dismiss+undo cycles in 12618 ms (1000 undos): 8 rows, toast open: false, transient callbacks: 0, RSS 357 → 396 MB
[stress] year chart entrance (365 points): 60 frames, avg 2.21 ms, p90 3.69 ms, p99 36.81 ms, > 16 ms: 1
[stress] 10 period switches (30 frames each): 300 frames, avg 1.99 ms, p90 2.60 ms, p99 15.55 ms, > 16 ms: 2
[stress] 500 notifications entrance: 60 frames, avg 0.89 ms, p90 1.02 ms, p99 2.61 ms, > 16 ms: 0
[stress] 500 notifications, 40 scroll frames: 40 frames, avg 12.45 ms, p90 15.91 ms, p99 18.78 ms, > 16 ms: 3
[stress] mark all read: 250 ids in one write, 17 ms
[stress] 50-card stack, tilt at 60 Hz: 300 frames, avg 1.25 ms, p90 1.66 ms, p99 2.37 ms, > 16 ms: 0
[stress] 20 flips under tilt: 600 frames, avg 1.12 ms, p90 1.51 ms, p99 5.46 ms, > 16 ms: 0
[stress] 10 swipes under tilt: 200 frames, avg 1.49 ms, p90 1.58 ms, p99 10.38 ms, > 16 ms: 0
[stress] tickers after dispose: 0, sensor listeners: 0
[stress] 10k transactions: seed 208 ms, home ready in 100 ms, rows on screen: 5, RSS 331 MB
[stress] 1000 hide-balance taps in 409 ms: hidden=false, persisted=false, writes=1000
[stress] 1000 add-card taps in 307 ms: stored=1, location=/cards
[stress] odometer to max at 1.3x: 60 frames, avg 1.24 ms, p90 2.94 ms, p99 6.53 ms, > 16 ms: 0
STRESS slider: 1,002 gestures in 491 ms → 1 authorize, 1 ledger write(s)
STRESS 1,000 payments (100 flaky retries): 1943 ms, rows 1000, already paid 100, RSS 316 → 311 MB, effect listeners after: false
STRESS keypad: 10,000 inputs in 27025 ms; 10000 frames, avg 1.93 ms, p90 4.82 ms, p99 8.27 ms, > 16 ms: 15
STRESS confetti + odometer: 100 frames, avg 0.16 ms, p90 0.29 ms, p99 1.59 ms, > 16 ms: 0
STRESS 50 contacts entrance: 60 frames, avg 0.21 ms, p90 0.47 ms, p99 1.55 ms, > 16 ms: 0; search filter 45490 µs
```

### Coverage (`flutter test --coverage --concurrency=4`, `dart run tool/coverage_summary.dart`)

| Folder | Lines hit | Lines found | Coverage |
|---|---:|---:|---:|
| `lib (root)` | 36 | 41 | 87.8 % |
| `lib/blocs` | 397 | 441 | 90.0 % |
| `lib/core` | 538 | 609 | 88.3 % |
| `lib/data` | 394 | 397 | 99.2 % |
| `lib/design_system` | 2656 | 2720 | 97.6 % |
| `lib/domain` | 100 | 113 | 88.5 % |
| `lib/models` | 165 | 167 | 98.8 % |
| `lib/routes` | 126 | 129 | 97.7 % |
| `lib/screens` | 5347 | 5458 | 98.0 % |
| `lib/utils` | 48 | 48 | 100.0 % |
| **lib (total)** | 9807 | 10123 | 96.9 % |

Targets (spec §6, ≥ 80 % on `lib/domain`, `lib/data`, `lib/blocs`, `lib/design_system`): all met (88.5 / 99.2 / 90.0 / 97.6 %). `lib/core` 88.3 % is the real platform implementations (secure storage, biometrics, vibration, sensors, the `FLAG_SECURE` channel), which only a device exercises.

### Integration tests

`integration_test/app_flows_test.dart` (onboarding → login → send money → swipe to pay → success → history; add card → stack; Test Decline) and `integration_test/perf_test.dart` compile and pass `flutter analyze`; **not run: no device**. Commands in README "Tests".
