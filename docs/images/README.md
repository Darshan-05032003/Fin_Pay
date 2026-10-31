# Screenshots and recordings

The PNGs in this folder are copied from the golden baselines, so they are
rendered by the test suite (Linux host, bundled Manrope / Instrument Serif,
Material icons render as boxes, D-009):

| File | What it shows | Source golden |
|---|---|---|
| `gallery_1_0.png` | The whole design-system gallery (`/gallery`) at 1.0× text scale | `test/golden/design_system/goldens/gallery_1_0.png` |
| `tokens_1_0.png` | Colour, spacing, depth and typography tokens | `test/golden/design_system/goldens/tokens_1_0.png` |
| `buttons_1_0.png` | `FpButton` in every variant, size and state | `test/golden/design_system/goldens/buttons_1_0.png` |

Every screen state also has a golden under `test/golden/screens/goldens/`
(120 files, 1.0× and 1.3×); open them directly for a static view of any
screen.

## Recordings to capture on a phone

Motion does not survive a golden. Record the flows below on a device
(`adb shell screenrecord`, or the Android Studio recorder), trim to 5–10 s,
convert to GIF or WebP at ≤ 480 px wide, and save them here with the names
in the first column. The README links to them by these names.

| File name | Flow | What to show |
|---|---|---|
| `onboarding.gif` | Welcome → onboarding | Serif wordmark reveal, CTAs rising on a spring, three-layer parallax while paging, morphing page indicator |
| `login.gif` | Login | Inline validation, shake + haptic on a wrong password, spinner morph, fade-through to home |
| `home_header.gif` | Home | Balance odometer count-up, header collapsing and docking beside the eye on scroll, hide-balance mask |
| `card_stack.gif` | Cards tab | Pile → spring fan-out into the perspective carousel, tilt with sheen, tap to flip, timed CVV reveal |
| `add_card.gif` | Add card | Live card preview with the BIN cross-fade (Visa → Mastercard → RuPay), Luhn/expiry/CVV validation |
| `swipe_to_pay.gif` | Send money → review → success | Keypad with rolling digits, review sheet on a spring, swipe-to-pay ticks and snap-back, processing ring, drawn check + confetti |
| `payment_failure.gif` | "Test Decline" / "Test Timeout" | Drawn cross + shake, Retry → "already paid" on the timeout contact |
| `statistics.gif` | Stats tab | Bars growing, line drawing on, donut sweeping, period switcher indicator |
| `transactions.gif` | History | Sticky day headers, search and filter chips, swipe actions with Delete + Undo toast |
| `profile.gif` | Profile | Parallax avatar header, NeoPOP toggles (haptics, reduce motion, hide balance), logout sheet |

Suggested device: a mid-range phone in profile mode (`flutter run --profile`),
with "Reduce motion" off so the full motion is recorded.
