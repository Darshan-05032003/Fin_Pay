# Load / performance report

One entry per feature (spec §7b). Stress tests live in `test/stress/`, tag
`stress`, and only run with:

```
flutter test --tags stress --dart-define=FINPAY_STRESS=true --concurrency=1 test/stress
```

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
