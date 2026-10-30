# FinPay UI Audit (pre-upgrade baseline)

Scope: every file under `lib/screens/`, `lib/widgets/` (including `lib/widgets/animations/`), `lib/constants/theme.dart`, `lib/main.dart`, `lib/routes/app_router.dart`. All `file:line` references were checked against the current tree. Line counts are from `wc -l`. Contrast ratios are WCAG 2.1 relative-luminance calculations, rounded.

Companion docs: `docs/PLAN.md` (waves and ownership). Target primitives below refer to the planned `lib/design_system/` layout: `tokens/`, `theme/`, `typography/`, `components/` (NeoPOP widgets), `motion/` (motion primitives).

---

## 1. Top 10 problems (ranked)

| # | Problem | Evidence | Impact |
|---|---|---|---|
| 1 | **No design system. Every screen hand-rolls its own UI.** Theme `textTheme` is never read (0 uses of `Theme.of(context)` in `lib/screens/`). The focus-bordered text field block is pasted 14 times. The orange-gradient CTA (`CredButtonPress > SpringAnimation > Container(gradient, glow)`) is pasted 10 times. There are 8 corner radii (4, 8, 12, 16, 20, 24, 30, 2), 16 font sizes (10 to 56) and 5 weights. `lib/utils/helpers.dart` (currency/date formatting) and `lib/utils/validators.dart` exist but no screen uses them. | e.g. `login_screen.dart:98-129`, `add_card_screen.dart:66-228`, `verification_screen.dart:278-305` | Inconsistent look, very high cost to restyle |
| 2 | **The style is not NeoPOP.** CRED NeoPOP uses flat surfaces with sharp corners, solid extruded edges and a "plunk" press. FinPay uses rounded 16 to 30 px cards with soft blurred orange glows (`blurRadius: 20`, `credOrangeSunshine.withOpacity(0.4)`, 27 gradient uses in screens). Surface `#0F0F0F` on background `#0D0D0D` is about 1.02:1, so cards do not separate from the page. The only NeoPOP widgets (`lib/widgets/neopop_button.dart`) are **unused**. | `theme.dart:8-9`, `neopop_button.dart` (0 usages) | Looks like a generic Dribbble template |
| 3 | **Motion overload with no restraint and no reduce-motion support.** In screens: 88 `CredSlideIn`, 39 `CredCardReveal`, 22 `FadeInAnimation`, 12 `SpringAnimation`, often nested 2 to 3 deep on one widget (double fades). 16 **infinite** `PulseAnimation`s run across 12 screens. `MediaQuery.disableAnimations` appears 0 times in `lib/`. | e.g. `home_screen.dart:588-596`, `onboarding_screen.dart:221-227` | Distracting and tiring to watch; fails accessibility expectations |
| 4 | **`CredSlideIn` offset bug.** It feeds pixel-like values (`Offset(0, 30)` default, also 20, 40, 50) into `SlideTransition`, which reads offsets as *fractions of the child's size*. Widgets start 20 to 50 child-heights or widths away and streak in. `DelayedAnimation` has the same bug (`Offset(-20,0)` on the success screen). | `cred_slide_in.dart:10,39-45,73-74`; `delayed_animation.dart:10,41-44` | Most visible source of "janky" motion |
| 5 | **Accessibility is effectively absent.** 0 `Semantics`, `semanticLabel` or `tooltip` uses. Text scaling is forced to 1.0 (`main.dart:74-81`). White text on the orange CTA is about 2.3:1. Grey `#B0B0B0` on the orange header is about 1.1:1. 9 Material buttons are wrapped with `onPressed: null`, so screen readers announce them as *disabled*. Several touch targets are under 48 dp. | §2 per screen; `grep "onPressed: null"` | Fails WCAG AA; unusable with TalkBack/VoiceOver |
| 6 | **Navigation architecture is broken.** Tabs switch with `pushReplacementNamed` (state is lost and the entrance animations replay). The tab onTap switch is copy-pasted in 4 files. Tab screens show a back arrow. The route stack after login is `[Welcome, Home]`, so system back on Home returns to the Welcome splash. `initialRoute: '/'` ignores auth state. `go_router` is a dependency but unused. | `home_screen.dart:145-158`, `statistics_screen.dart:68-74`, `main.dart:72-73`, `app_router.dart:25` | Feels broken; nothing persists between tabs |
| 7 | **Fake or placeholder content and dead controls in production UI.** Demo credentials are printed on the login and sign-up screens. Sender "Amir" and the "TXN 30342303" ID are hardcoded. The statistics chart is static (fake Sep to Dec bars and axis labels). The privacy URL is `https://your-domain.com/...`. Over 15 controls do nothing (`onTap: () {}`, or only a haptic). | `login_screen.dart:149`, `transfer_review_screen.dart:86,251`, `statistics_screen.dart:263-284`, `profile_screen.dart:380` | Amateur; breaks trust in a payments app |
| 8 | **Missing or incorrect states.** No error state anywhere (BLoC error states and `UserService` failures are ignored). No in-flight state on login or transfer confirm, so a double tap can submit a transfer twice. Empty states are plain grey text. Search with no results shows a blank list on Notifications. `setState` runs after `await` without a `mounted` check in 6 screens. | `transfer_review_screen.dart:149-207`, `my_cards_screen.dart:30-36`, `transfer_screen.dart:39-45`, `transactions_screen.dart:32-38`, `statistics_screen.dart:37-60`, `notifications_screen.dart:35-52`, `profile_screen.dart:34-40` | Crashes, duplicate payments, confusing UX |
| 9 | **Performance risks.** `Opacity` is animated inside builders in 10 files, 8 of them on live code paths (each frame forces a saveLayer). The whole Welcome column is wrapped in an animated `Opacity`. Keypad taps call `setState` on the whole Transfer screen. Lists are built with `...map()` inside `Column`/`ListView(children:)`. Entrance delays grow without bound with list index (`300 + index*50` ms). 16 always-running tickers come from pulses. | `welcome_screen.dart:49-56`, `transfer_screen.dart:512-524`, `transactions_screen.dart:207-211` | Jank on mid-range Android |
| 10 | **Theme debt and functional bugs on the UI surface.** 25 legacy colour aliases, several with misleading names (`credPurple` is orange, `textDark` is white). `darkTheme` is set to `lightTheme`. The `Inter` font is declared but not bundled. `statistics_screen.dart:40-56` assigns `double` into `var x = 0` (int); analyzer should reject this, verify in F0. The Logout button bypasses its confirmation dialog. The flipped card face is mirrored. `SwipeToDismiss` leaves a dismissed `Dismissible` in the tree. | §4; `profile_screen.dart:459-534`; `card_3d_flip.dart:71-76`; `swipe_to_dismiss.dart:60-74` | Bugs users will hit |

---

## 2. Screen-by-screen

Shared notes, not repeated per screen:
- Every screen hardcodes `backgroundColor: AppTheme.credPureBackground` and builds `TextStyle(...)` inline instead of using `textTheme`.
- No screen has `Semantics`, honours reduce-motion, or allows text scaling (`main.dart:78`).
- Most CTAs use white text (`credWhite` `#F8F8F8`) on the orange gradient (`#FF8744` to `#E66A00`): about **2.3:1 to 3.1:1**, fails AA. Dark text (`#0F0F0F`) on `#FF8744` is about 8:1.
- The "orange glow" shadow `BoxShadow(color: credOrangeSunshine.withOpacity(0.4), blurRadius: 20, offset: (0,10))` recurs throughout and is not a NeoPOP shadow.

### 2.1 Welcome: `lib/screens/onboarding/welcome_screen.dart` (139 lines)
- **Looks amateur:** The wordmark is plain `Text('FinPay')` at 56 px w800 with an endless pulse (`:60-72`). "Your money. Your move" has no full stop and no visual hierarchy. Material `ElevatedButton` with `elevation: 8` (`:104-116`) is off-brand. Indentation is broken at `:109-110`.
- **Tokens/magic numbers:** `Duration(milliseconds: 1500)` `:23`; slide `50` px `:31`; `fontSize: 56` `:67`; `20` `:80`; `EdgeInsets.all(32)` `:90`; `Duration(milliseconds: 600)` `:93`; `Size(double.infinity, 60)` `:111`; radius `16` `:113`; delays 500/800 ms `:75,88`.
- **Missing states:** It always shows, even for a logged-in user (no auth redirect). No splash-to-content handoff.
- **Jank:** The whole `Column` is wrapped in `AnimatedBuilder > Opacity > Transform` (`:49-56`), which re-lays out the full tree for 1.5 s. A nested `TweenAnimationBuilder > Opacity` (`:91-103`) starts at mount while its parent `FadeInAnimation` is still delayed, so the scale-in is half over before it is visible.
- **A11y:** CTA white on orange is about 2.3:1. The logo pulse is not a reduce-motion candidate.
- **Animation widgets:** `FadeInAnimation`, `PulseAnimation`, plus an inline `AnimationController`/`TweenAnimationBuilder`.

### 2.2 Onboarding: `lib/screens/onboarding/onboarding_screen.dart` (280 lines)
- **Looks amateur:** Two "Skip" buttons are visible at once (top right `:47-70`, bottom left `:106-120`). Illustrations are Material icons at 100 px in a 220 px orange rounded square (`:231-247`). The copy repeats itself across all three pages. Dots are a stock `WormEffect` (`:91-96`).
- **Tokens/magic numbers:** radius `16` `:139`, `30` `:235`; `EdgeInsets.all(32)` `:186`; `SizedBox(height: 40/16/48)` `:190,205,220`; `dotHeight/dotWidth: 10` `:94-95`; `nextPage(Duration(400), Curves.easeInOutCubic)` `:126-128`; per-page delays `200/300/400 + index*100` `:192,207,222`; `CredCardReveal(Duration(800), perspective: 0.0008)` `:224-226`.
- **Missing states:** None needed beyond the content. "Continue" does not change to "Get started" on the last page.
- **Jank:** `TweenAnimationBuilder > Opacity` per page (`:176-184`). Every page stacks `CredSlideIn > CredCardReveal > PulseAnimation`, so 3 controllers plus an infinite pulse per page. `CredSlideIn` delays include `index*100`, so later pages animate in later for no reason.
- **A11y:** "Continue" is white on orange (about 2.3:1). The bottom "Skip" is bare text with no padding (touch target about 20 dp, `:107-119`). `Navigator` is used after `await` without a `mounted` check (`:54-55, :109-110`).
- **Animation widgets:** `CredSlideIn`, `CredButtonPress`, `SpringAnimation`, `CredCardReveal`, `PulseAnimation`, `SmoothPageIndicator`.

### 2.3 Login: `lib/screens/auth/login_screen.dart` (403 lines)
- **Looks amateur:** Demo credentials are shown in an orange info box (`:131-160`) and repeated in the error snackbar (`:273`). Social logins are fake: `Icons.g_mobiledata` stands in for Google and `Icons.send` for Telegram. They pulse forever and do nothing (`:337-341, :375-402`). "Biometric Login" is plain text that looks like a control (`:226-229`).
- **Tokens/magic numbers:** `AnimationController(1200ms)` created and forwarded but **never used** (`:23-32`); radius `16` `:107,180,289`, `12` `:138`; `contentPadding: EdgeInsets.all(20)` `:123,212`; `fontSize: 36` `:70`; delays 100 to 900 ms in steps of 100 (`:66-347`); social `56x56` `:387-388`.
- **Missing states:** No loading indicator while `UserService.loginUser` runs (`:267`). No inline field errors (`Validators` unused). No `keyboardType`, `textInputAction` or `autofillHints`. No lockout or attempt feedback.
- **Jank:** Two 14-line copies of the focus-field block (`:98-129`, `:171-218`). 3 infinite pulses on social icons.
- **A11y:** The password visibility toggle is `IconButton(onPressed: null)` inside `CredButtonPress` (`:196-210`), so it is announced as disabled. Social buttons have no labels. `ScaffoldMessenger`/`Navigator` are used after `await` (`:252, :271, :282`).
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `CredButtonPress`, `FadeInAnimation`, `SpringAnimation`, `PulseAnimation`.

### 2.4 Create account: `lib/screens/auth/create_account_screen.dart` (405 lines)
- **Looks amateur:** "Only default credentials work: …" banner (`:170`). Social icons use raw Material colours `Colors.red/blue/lightBlue` (`:334-338`), unlike Login, which uses theme colours. Terms text is not tappable (`:243-253`).
- **Tokens/magic numbers:** 3 copies of the focus field (`:76-107`, `:119-150`, `:192-239`); `CredCardReveal` durations 500/600/700 (`:74,114,190`); `EdgeInsets.all(20)`; radius `16`/`12`/`28` (`:377`); `Curves.easeOutBack` 600 ms (`:371-372`).
- **Missing states:** No password-strength feedback, no field validation, no loading state. The **plain-text password is passed as a route argument** (`:274-284`).
- **Jank:** `_buildSocialIcon` rebuilds `RippleEffect` and its child inside the `TweenAnimationBuilder` builder instead of using `child` (`:369-394`).
- **A11y:** Same disabled-`IconButton` toggle (`:217-231`). No password rules are announced.
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `CredButtonPress`, `FadeInAnimation`, `SpringAnimation`, `RippleEffect`.

### 2.5 Verification / OTP: `lib/screens/auth/verification_screen.dart` (328 lines)
- **Looks amateur:** A pulsing green "check" badge appears **before** verification (`:66-92`). The heading has an exclamation mark ("Enter Verification Code!"). "Resend It" does nothing and has no countdown (`:209-220`). **Any 4 digits are accepted**; only the credentials are checked (`:230-276`).
- **Tokens/magic numbers:** card radius `20` `:46`; field `width: 60` `:144`; `fontSize: 28` `:109,169`; delays `600 + index*50` and durations `400 + index*50` (`:138,141`); orange glow `blurRadius: 24` `:51-55`.
- **Missing states:** No error shake or red state on a wrong code. No resend timer. No paste support or `AutofillHints.oneTimeCode`. Backspace on an empty box does not move focus back (only `onChanged` is handled, `:179-186`). No loading state while saving the user.
- **Jank:** 4 boxes x (`CredSlideIn` + `CredCardReveal`) = 8 controllers for one row.
- **A11y:** There is no `Scaffold` app bar and **no `SafeArea` or scroll view**, so `Center > Column` will overflow when the keyboard opens on small phones (`:35-41`). The close control is a bare 24 dp `Icon` (`:93-99`). Digit boxes have no labels ("digit 1 of 4").
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `PulseAnimation`, `CredButtonPress`, `SpringAnimation`.

### 2.6 Forgot password: `lib/screens/auth/forgot_password_screen.dart` (238 lines)
- **Looks amateur:** Both recovery options are no-ops (`:99-101`, `:112-114`). "Continue" just pops the screen (`:121-123`). There is no email or phone input and no selected-option state. A 200 px pulsing shield icon fills the screen (`:63-88`).
- **Tokens/magic numbers:** radius `30` `:72`, `20` `:176`, `16` `:130,191`; `fontSize: 13` `:219`; `SizedBox(height: 48)` x2 `:56,91`.
- **Missing states:** Selection, sending, sent (with check-your-inbox) and error states are all missing.
- **Jank:** Each option is `CredButtonPress > CredCardReveal > Row` with its own infinite pulse (`:168-201`).
- **A11y:** Options are not exposed as radio or selected. Back arrow has no tooltip.
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `PulseAnimation`, `CredButtonPress`, `SpringAnimation`.

### 2.7 Fingerprint setup: `lib/screens/auth/fingerprint_setup_screen.dart` (151 lines)
- **Looks amateur:** A 220 px orange circle with a 120 px icon (`:68-87`). The CTA "Set Up Fingerprint" skips biometrics entirely and goes home (`:109-111`). There is no "Not now" option.
- **Tokens/magic numbers:** `PulseAnimation(maxScale: 1.05)` `:65-66`; `fontSize: 36` `:37`; spacing `32/12/48/32/48/16` (`:31-143`).
- **Missing states:** Scanning, success, failure, "biometrics unavailable" and skip are all missing. `local_auth` is not integrated.
- **Jank:** Minor. One infinite pulse.
- **A11y:** Large decorative icon without `excludeSemantics`. CTA contrast fails.
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `PulseAnimation`, `CredButtonPress`, `SpringAnimation`.

### 2.8 Home: `lib/screens/home/home_screen.dart` (1017 lines)
- **Looks amateur:**
  - The header is a full orange gradient slab (`:210-218`). Grey `credTextSecondary` text sits on it ("Good Morning", "Available Balance", `:249,322`) at about 1.1:1.
  - Bill-pay tiles use a random palette: `credOrange`, `credError` for Electricity, `credBlue`, neon green, and orange at 0.7 opacity (`:526-573`).
  - The promo "40%" pulses forever (`:763-774`). "Recent Transaction" is singular (`:812`).
  - The FAB uses `IconMorph(send → send)`, which does nothing (`:180-185`), plus an elastic slide-in and an infinite pulse (`:159-189`).
- **Tokens/magic numbers:** quick-action circles 56 px (`:374`); payment tiles 64 px radius 16 (`:609-613`); `fontSize: 11` `:397`; grid `crossAxisCount: 4, spacing 12, childAspectRatio 0.85` (`:521-524`); payment item delays `500 + index*60` with durations `500 + index*50` (`:589-593`); `Curves.easeOutBack` (`:591`); `Curves.elasticOut` (`:163`); FAB `elevation: 12` (`:179`); currency `'\$${amount.toStringAsFixed(2)}'` (`:943`, no thousands separator; `Helpers.formatCurrency` unused).
- **Dead code:** `_FloatingActionButtonWithDelay` (`:26-80`) is never used. `_buildQuickActions()` returns a `SizedBox` (`:496-498`). `_formatDate` is duplicated in 3 screens (`:985-996`).
- **Missing states:** No error state for `UserError`/`TransactionError`. The loading skeleton is a **nested `Scaffold` inside a `Scaffold`** (`:104-108` plus `:998-1016`). Pull-to-refresh fires events and returns immediately, so the spinner closes before data arrives (`:119-124`). Transaction rows do nothing on tap (`:870-873`). The `billType` argument passed to `/transfer` is ignored by `TransferScreen` (`:663-668`).
- **Jank:** Two nested `BlocBuilder`s rebuild the whole screen, including every entrance animation subtree, on any user or transaction state change (`:92-95`). `TweenAnimationBuilder > Opacity` in the header (`:232-245`). 5 infinite pulses on quick actions (`:370-372`) plus FAB plus promo = 7 tickers. The recent list is `...map()` in a `Column` (`:854-861`). `StaggeredListAnimation` grows *duration* (not delay) with index.
- **A11y:** The bell and settings icons are `IconButton(onPressed: null)` inside `RippleEffect` (`:276-307`), so they are announced as disabled with no tooltip. The FAB is `onPressed: null` (`:176-177`). "See All" is `TextButton(onPressed: null)` (`:828-834`). The "More" bottom sheet pops and then calls `ScaffoldMessenger.of(context)` with the **sheet's** disposed context (`:455-469`).
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `CredButtonPress`, `FadeInAnimation` (as `custom.`), `CredNumberCounter`, `IconMorph`, `PulseAnimation`, `RippleEffect`, `StaggeredListAnimation`, `CustomPullToRefresh`, `SkeletonLoader`/`SkeletonList`, `CredBottomNavigationBar`.

### 2.9 My cards: `lib/screens/cards/my_cards_screen.dart` (416 lines)
- **Looks amateur:** The title is "My Card" (`:43`). All cards share one flat orange gradient. The brand is a text label ("VISA"/"MASTERCARD"). **The CVV is shown in plain text on the card back** (`:296-303`). Details are shown only for `_cards.first` (`:132-135`). Card type is printed via `toString().split('.')` (`:356`).
- **Tokens/magic numbers:** card `height: 200`, radius `20`, padding `24` (`:155-159`); shadow `spreadRadius: 5`, `blurRadius: 20` (`:161-166`); detail radius `12` (`:340`); `Colors.black.withOpacity(0.3)` magstripe (`:285`); `Colors.white.withOpacity(0.2)` CVV box (`:293`); `'\$${card.balance.toStringAsFixed(2)}'` (`:354`).
- **Missing states:** Loading is a bare `CircularProgressIndicator` (`:50`). The empty state is one grey line (`:56-68`). No error state. It reads `UserService` directly instead of the provided `CardBloc`. `setState` runs after `await` without `mounted` (`:30-36`).
- **Jank:** `TweenAnimationBuilder > Opacity` per card, and the shadow colour and offset are animated every frame (`:145-166`). Card list is `...map()` (`:70-85`).
- **Bugs:** `Card3DFlip` renders the back face without a counter-rotation, so the back appears **mirrored** (`card_3d_flip.dart:71-76`). "Add New Card" is `ElevatedButton(onPressed: null)` (`:113-114`), so it renders with *disabled* foreground colours and is announced as disabled. Navigation goes through a raw `MaterialPageRoute`, bypassing the router (`:93-98`). It is a tab screen but shows a back arrow (`:44-47`).
- **A11y:** Cards have no semantic summary ("Visa ending 1234, expires 08/27"). Flip-on-tap is not discoverable or labelled.
- **Animation widgets:** `Card3DFlip`, `StaggeredListAnimation`, `FadeInAnimation`, `RippleEffect`, `CredBottomNavigationBar`.

### 2.10 Add card: `lib/screens/cards/add_card_screen.dart` (604 lines)
- **Looks amateur:** The "live" preview **never updates while typing**. There are no controller listeners; it only rebuilds when the card type changes (`:316-424`). It always shows "VISA" (`:342`). The card-type picker uses three hand-copied rows (`:450-541`). The string sentinel `'Select card type'` (`:25, :234, :579`) doubles as state.
- **Tokens/magic numbers:** 4 copies of the focus field (`:66-228`); `CredCardReveal` durations 600, 700, 800, 900, 1000, 1100 ms (`:46,55,64,104,148,188`); preview `height: 220`, radius `24` (`:321-325`); `fontSize: 28/22` (`:345,361`).
- **Missing states:**
  - No input formatters: no card-number grouping, Luhn check, length limits, MM/YY mask or CVV `maxLength` (`:123-219`).
  - No inline errors and no saving or loading state.
  - The success snackbar uses neon green `#E5FE40` with the theme's white text, about **1.06:1** (`:272-277`).
  - `_cardTypeController` is unused (`:20`).
- **Jank:** 6 staggered reveals, each 100 ms longer than the last. The preview pulses forever (`:317`).
- **A11y:** No `SafeArea` (`:38`). The picker sheet rows have no selected state. Sensitive fields (number, CVV) have no `autofillHints`.
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `CredButtonPress`, `PulseAnimation`, `SpringAnimation`.

### 2.11 Transfer: `lib/screens/transfer/transfer_screen.dart` (559 lines)
- **Looks amateur:**
  - Recipients are a hardcoded list; two of them share the avatar "J" (`:26-31`). "Add recipient" is a no-op (`:85-89`).
  - The amount `TextField` (system keyboard) and a custom keypad both edit the same value (`:207-232`, `:474-501`). Tapping the field opens the OS keyboard over the keypad.
  - Backspace is a "⌫" glyph coloured as an error (`:497, :544`).
- **Tokens/magic numbers:** avatar `60x60` (`:124-125`); `fontSize: 42` x3 (`:210,220,228`); keypad `childAspectRatio: 2`, spacing 12 (`:482-484`); per-key delay `700 + index*30` (`:505`); per-recipient `150 + index*50` (`:107`).
- **Missing states:** The Continue enabled-state is only recomputed when `setState` runs. Typing with the system keyboard leaves the button stale (`:273, :316-342`). Nothing limits input to 2 decimals or caps the length (`:518-524`). No inline over-balance warning (only a snackbar). Loading uses a generic `SkeletonList` (`:59`). `setState` after `await` without `mounted` (`:39-45`).
- **Jank:** Each keypad tap calls `setState` on the whole screen (`:512-524`). `PulseAnimation(minScale: isSelected ? ... : 1.0)` (`:120-122`) has no `didUpdateWidget`. Unselected avatars run a no-op ticker, and selection never starts the pulse. 12 keys x (`CredSlideIn` + `CredCardReveal`) = 24 controllers.
- **A11y:** Keys have no semantic labels ("⌫" is read literally). "Change" is `TextButton(onPressed: null)` (`:458-459`). The amount is not announced as currency.
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `CredButtonPress`, `SpringAnimation`, `PulseAnimation`, `CredNumberCounter`, `SkeletonList`.

### 2.12 Transfer review: `lib/screens/transfer/transfer_review_screen.dart` (347 lines)
- **Looks amateur:** The sender is hardcoded as "Amir" (`:251`). The transaction ID is hardcoded as "TXN 30342303" (`:86`). The sender/recipient row is wrapped in `DraggableCard` with no-op swipe callbacks (`:62-66`): a user can fling the card off-screen and it never comes back. The "Reference" field is a `const TextField` with no controller and a static `counterText: '0/50'` (`:127-138`), so the note is discarded. Router defaults invent data (`'Kelvin Habit'`, `'420.90'`, `app_router.dart:48-50`).
- **Tokens/magic numbers:** `Divider(thickness: 0.5)` x4 (`:87-93`); avatar 64 px (`:283-284`); legacy alias `AppTheme.red` (`:156,168`); `HapticService.heavyImpact()` before a commit (`:174`).
- **Missing states:** No in-flight or disabled state, so a double tap creates two transactions (`:149-207`). No PIN, biometric or slide-to-confirm step. No failure path or retry. `Navigator`/`ScaffoldMessenger` are used after several `await`s in a `StatelessWidget`.
- **Jank:** `DraggableCard` calls `setState` and fires a haptic **on every pan frame** (`draggable_card.dart:70-76`). Infinite pulses on both avatars (`:279-306`).
- **A11y:** Draggable content is not announced. The total amount is not grouped semantically.
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `DraggableCard`, `CredButtonPress`, `SpringAnimation`, `PulseAnimation`.

### 2.13 Transfer success: `lib/screens/transfer/transfer_success_screen.dart` (322 lines)
- **Looks amateur:**
  - The AppBar title is "Review" (`:67`) and it shows a back arrow back into the transfer flow (`:68-71`).
  - The copy says "withdraw summary" (`:148`).
  - Avatars are hardcoded "A/Amir" and "K" regardless of recipient (`:177, :196`).
  - A green check has an *orange* glow (`:105-116`). Confetti uses Material rainbow colours (`confetti_effect.dart:62-87`).
  - "Return to Home" is a stock `ElevatedButton(elevation: 4)` (`:245-267`).
- **Tokens/magic numbers:** `2 * 3.14159` instead of `math.pi` (`:41`); 1200 ms controller with `Interval(0, 0.6, elasticOut)` (`:30-38`); `Colors.black.withOpacity(0.1)` (`:83`); delays 400 to 1200 ms (`:132-244`).
- **Missing states:** No receipt, share action or transaction ID. `double.parse(widget.amount)` throws on bad input (`:221`).
- **Jank:** The count-up `TweenAnimationBuilder` starts at mount while `DelayedAnimation` hides it for 1000 ms, so it is mostly finished before it appears (`:216-237`). Two confetti emitters of 50 particles each.
- **A11y:** The success state is not announced (no live region). Confetti ignores reduce-motion.
- **Animation widgets:** `ConfettiEffect`, `DelayedAnimation`, `FadeInAnimation`, inline `AnimationController` (scale plus 360° spin).

### 2.14 Transactions: `lib/screens/transactions/transactions_screen.dart` (348 lines)
- **Looks amateur:** The title is "Transaction" (`:55`). The filter (`:120-123`) and dropdown (`:145-148`) buttons are no-ops. **Swipe-to-delete removes financial records** with no confirmation or undo (`:212-220`). There is no date grouping, and tags use `fontSize: 10` (`:324`).
- **Tokens/magic numbers:** radius `16`/`20`/`4`; delays `300 + index*50` and durations `400 + index*30` (`:208-210`); `_formatDate` duplicate (`:336-347`).
- **Missing states:** The empty state cannot be pulled to refresh (`:175-197`). No error state. `setState` after `await` without `mounted` (`:32-38`). Search does not debounce, and a haptic fires **on every keystroke** (`:95-100`).
- **Jank:** `AnimationLimiter` (flutter_staggered_animations) wraps a list with no `AnimationConfiguration` children, so it does nothing (`:200`). Each recycled row replays its slide-in, and row 40 waits 2.3 s. `_filteredTransactions` is a getter that re-filters on every call (it is called 3 times per build).
- **Bug:** `SwipeToDismiss` awaits a haptic and a 300 ms animation before calling `onDismiss` (`swipe_to_dismiss.dart:60-67`). Flutter asserts "A dismissed Dismissible widget is still part of the tree."
- **A11y:** Rows are `CredButtonPress` with no action and no semantics. The swipe action has no accessible alternative.
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `CredButtonPress`, `SwipeToDismiss`, `CustomPullToRefresh`, `SkeletonList`, `AnimationLimiter` (unused).

### 2.15 Statistics: `lib/screens/statistics/statistics_screen.dart` (507 lines)
- **Looks amateur:** The title is "Statics" (`:67`). **The chart is fake**: fixed Sep to Dec bars (`:281-284`) and an axis labelled 10K to 40K (`:263-266`) that has nothing to do with the data. The "Monthly" selector is a no-op (`:104-107`). "Recent Transaction" shows only one item (`:57`) and always styles it as a red "Payment", even income (`:406-469`).
- **Tokens/magic numbers:** chart `height: 220`, radius `12` (`:251-255`); bar `width: 50`, radius `4` (`:302-308`); `maxBarHeight = 160.0`, `- 25` (`:273-274`); stat card radius `20`; `fontSize: 11` (`:316`).
- **Probable compile error:** `var totalSpending = 0;` (int) then `+= transaction.amount.abs()` (double), and assigning it to `double _totalSpending` (`:40-56`). Confirm with `flutter analyze` in F0.
- **Missing states:** No error state. No empty-chart state. Pull-to-refresh is wired, but the chart cannot change.
- **Jank:** Mixes three entrance systems in one column: `CredSlideIn`, `AnimationConfiguration.staggeredList` + `SlideAnimation`, and `custom.FadeInAnimation` (`:87-239`). A `custom.` import prefix is needed because of a name clash with the package's `FadeInAnimation` (`:9`). Infinite pulse on each stat card icon (`:346`).
- **A11y:** The chart has no semantic description. It is a tab screen with a back arrow (`:68-74`).
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `CredButtonPress`, `CredNumberCounter`, `FadeInAnimation`, `PulseAnimation`, `CustomPullToRefresh`, `SkeletonList`, `AnimationConfiguration`/`SlideAnimation` (package), `CredBottomNavigationBar`.

### 2.16 Notifications: `lib/screens/notifications/notifications_screen.dart` (379 lines)
- **Looks amateur:** **Notifications older than yesterday are silently dropped.** Only Today and Yesterday buckets are built (`:42-45`). Every type gets the same neon icon colour (`:293`). The filter is a no-op (`:141-144`). There is no read/unread state and rows do nothing on tap (`:223-226`).
- **Tokens/magic numbers:** item radius `12` (`:315`) vs `16`/`20` elsewhere; section header vertical padding `16` (`:279`); `'${difference.inMinutes}m'` shows "0m" for brand-new items (`:372`).
- **Missing states:** A search with no matches shows an empty list with no message. No error state.
- **Jank:** Today rows use `CredSlideIn > CredCardReveal`. Yesterday rows use `AnimationConfiguration > SlideAnimation > custom.FadeInAnimation` (`:205-265`). These are two motion languages in one list, built with non-builder `ListView(children:)` (`:195`). A haptic fires on every search keystroke (`:116-121`).
- **Bug:** The same `SwipeToDismiss` assertion as Transactions (`:213, :250`).
- **A11y:** Unread state is not announced. Dismiss has no accessible action.
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `CredButtonPress`, `FadeInAnimation`, `SwipeToDismiss`, `CustomPullToRefresh`, `SkeletonList`, `AnimationConfiguration`/`SlideAnimation` (package).

### 2.17 Profile: `lib/screens/profile/profile_screen.dart` (555 lines)
- **Looks amateur:** Every menu row has an orange gradient icon tile with a glow (`:417-431`). The Logout button is a solid red slab with a red glow (`:507-518`). The Edit Profile dialog is stock Material with default styling (`:259-302`). The privacy URL is a placeholder (`:380`). My Address, Security, Help Center and Invite Friends are no-ops (`:324,343,368,373`).
- **Tokens/magic numbers:** avatar 80 px, `fontSize: 32` (`:148-164`); header has no outer margin while sibling sections pad 16 (`:133-141` vs `:307,352,456`); radius `20`/`16`/`12`.
- **Missing states:** The loading `Scaffold` has no AppBar or nav (`:44-48`). The null-user state is plain text with no retry (`:51-65`). The edit dialog has no validation or saving state, and its controllers leak (never disposed, `:254-255`). `setState` after `await` without `mounted` (`:34-40`). `Navigator` is used after `await` (`:296`).
- **Bug:** Logout nests `RippleEffect(onTap: show confirm dialog)` around `CredButtonPress(onTap: logout immediately)` (`:459-534`). The inner tap recognizer wins the gesture arena, so **logout happens without confirmation**.
- **Jank:** Infinite pulse on the avatar (`:144`). Four stacked `CredSlideIn > CredCardReveal` sections.
- **A11y:** The edit icon is `IconButton(onPressed: null)` in `RippleEffect` (`:198-208`), announced as disabled. The destructive action is not marked.
- **Animation widgets:** `CredSlideIn`, `CredCardReveal`, `CredButtonPress`, `PulseAnimation`, `RippleEffect`, `SpringAnimation`, `CustomPullToRefresh`, `SkeletonList`, `CredBottomNavigationBar`.

### 2.18 Bottom nav: `lib/widgets/cred_bottom_navigation_bar.dart` (105 lines)
- **Looks amateur:** It is a stock `BottomNavigationBar` with an orange pill behind the icon. Unselected and selected pills use slightly different opacities (0.15 vs 0.2, `:81, :93`), and the unselected state is transparent anyway. Labels are Material defaults. There is no NeoPOP treatment.
- **Tokens/magic numbers:** `padding: EdgeInsets.all(8)`, radius `12`, icon `24` (`:78-99`); `selectedFontSize: 12` (`:33`); border `credMediumGray.withOpacity(0.3)` (`:22`).
- **Missing states:** No badge for unread notifications. No re-tap behaviour (scroll to top).
- **Jank:** The indicator pill snaps instead of animating. `HapticService.selection()` is awaited before `onTap` (`:41-44`). Each tab change calls `pushReplacementNamed` with the fade/scale route, so the whole screen and all its entrance animations rebuild. The onTap switch is duplicated 4 times (`home_screen.dart:147-157`, `my_cards_screen.dart:400-415`, `statistics_screen.dart:491-506`, `profile_screen.dart:539-554`).
- **A11y:** `BottomNavigationBar` provides basic semantics. Fine, but the tab state is lost on every switch.
- **Animation widgets:** none (static `Container`s).

---

## 3. Animation widget inventory

Usage counts are call sites in `lib/screens/` and `lib/routes/` (including `const` constructions). Verdict key: **KEEP→** migrate into the named `lib/design_system/` primitive; **MERGE** fold into the named primitive that duplicates it; **DELETE** remove (dead, broken or duplicate).

| Widget (file) | What it does | Used in | Quality notes | Verdict |
|---|---|---|---|---|
| `AnimatedButton` (`animations/animated_button.dart`, 92) | Scale to 0.95 on press, drops soft shadow, fires `onPressed` 100 ms after release | **unused** | Delayed callback via `Future.delayed` (`:59-61`); whole-widget `setState` | **DELETE** (duplicate of `CredButtonPress`) |
| `AnimatedGradient` (`animated_gradient.dart`, 69) | Oscillating linear gradient | **unused** | `child` passed to both `Container` and `AnimatedBuilder`; stops can cross | **DELETE** |
| `BouncingScrollPhysics` (`bouncing_scroll_physics.dart`, 23) | Custom physics that **shadows Flutter's class name** | **unused** (screens use Flutter's) | `applyPhysicsToUserOffset` returns raw offset (no overscroll resistance) | **DELETE** |
| `Card3DFlip` (`card_3d_flip.dart`, 83) | Tap to rotateY 0→π, swaps face at 90° | `my_cards_screen.dart:78` | Back face mirrored (no counter-rotation); `setState` wraps controller call; no Semantics/reduce-motion | **KEEP→** `motion/flip_card.dart` (fix back face, add drag-to-flip, reduce-motion crossfade) |
| `CelebratoryAnimation` (`celebratory_animation.dart`, 133) | Confetti + elastic scale + spin icon + `onComplete` after 3.8 s | **unused** | Async chain in `initState` without `mounted` checks | **DELETE** (duplicate of `ConfettiEffect` + success-screen inline check animation) |
| `ConfettiEffect` (`confetti_effect.dart`, 94) | Two confetti emitters (top + bottom) | `transfer_success_screen.dart:62` | Material rainbow colours; `play()/stop()` unreachable on private State; ignores reduce-motion | **KEEP→** `motion/celebration_burst.dart` (brand palette, single emitter, one-shot, reduce-motion off) |
| `CredButtonPress` (`cred_button_press.dart`, 85) | Scale 1→0.96 on press, `onTap` on tap-up | 39 sites / 14 screens | Has `RepaintBoundary`; no Semantics(button), focus, keyboard, disabled state or haptics; widely used to wrap *disabled* Material buttons | **KEEP→** `motion/pressable.dart` (base for all tappables; NeoPOP buttons build on it) |
| `CredCardReveal` (`cred_card_reveal.dart`, 87) | rotateX 0.1→0 + **Opacity** + 30 px translate | 39 sites / 13 screens | `Opacity` in builder (saveLayer/frame); nearly always nested inside `CredSlideIn`, so it double-fades | **MERGE** into `motion/entrance.dart` (as a `tilt` variant of `CredSlideIn`'s replacement) |
| `CredNumberCounter` (`cred_number_counter.dart`, 91) | Tweens a number, renders `prefix + toStringAsFixed` | `home_screen.dart:329`, `transfer_screen.dart:251`, `statistics_screen.dart:144,375` | **First build tweens value→value** (`:36-47`), so it never counts on first show; no tabular figures (width jitter); no grouping/locale | **KEEP→** `motion/animated_amount.dart` (odometer, int paise, tabular figures, `intl` formatting) |
| `CredPageTransition` (`cred_page_transition.dart`, 58) | Fade + scale 0.96 + 1 % slide route | `app_router.dart` (16 routes) | `curve` param stored but never applied (`:9,56`); fixed 250 ms reverse; no reduce-motion | **KEEP→** `motion/page_transitions.dart` (go_router `CustomTransitionPage`) |
| `CredSlideIn` (`cred_slide_in.dart`, 81) | Delayed `FadeTransition` + `SlideTransition` | 88 sites / 15 screens | **Offset is a fraction of child size but callers pass pixels** (default `Offset(0,30)`); `Future.delayed` start; good `RepaintBoundary` | **KEEP→** `motion/entrance.dart` as the single entrance primitive (pixel offsets, capped stagger, reduce-motion) |
| `CredStaggeredGrid` (`cred_staggered_grid.dart`, 122) | Grid with per-item scale/fade | **unused** | `Opacity` in builder | **DELETE** (duplicate of `StaggeredListAnimation`/entrance stagger) |
| `DelayedAnimation` (`delayed_animation.dart`, 70) | Delayed fade + slide | `transfer_success_screen.dart:173,192,216` | Same fractional-offset bug as `CredSlideIn` | **MERGE** into `motion/entrance.dart` (duplicate of `CredSlideIn`) |
| `DraggableCard` (`draggable_card.dart`, 195) | Pan to tilt, swipe out or elastic back | `transfer_review_screen.dart:62` (no-op callbacks) | Haptic + `setState` per pan frame (`:70-76`); `Opacity`; controller not reset after swipe-out so card is lost | **DELETE** (replace with `components/swipe_to_confirm.dart` on review) |
| `FadeInAnimation` (`fade_in_animation.dart`, 76) | Delayed fade + slide (0.2 fraction) | 22 sites / 8 screens | Name clashes with `flutter_staggered_animations` (forces `as custom` imports) | **MERGE** into `motion/entrance.dart` (duplicate of `CredSlideIn`) |
| `IconMorph` (`icon_morph.dart`, 80) | Swaps icon at 50 % with scale bump | `home_screen.dart:180,283,299` | All 3 uses inert (`send→send`; `animateOnTap:false`) | **DELETE** (use `AnimatedSwitcher` inside `components/neo_pop_icon_button.dart`) |
| `OptimizedAnimation` / `OptimizedListAnimation` / `OptimizedFadeIn` (`optimized_animation.dart`, 112) | Fade/scale/translate via `TweenAnimationBuilder` | **unused** | `Opacity` everywhere; `FutureBuilder(future: Future.delayed(...))` re-created each build | **DELETE** (duplicates of `CredSlideIn`/`StaggeredListAnimation`) |
| `ParallaxScroll` / `ParallaxWidget` (`parallax_scroll.dart`, 65) | Placeholder parallax | **unused** | `ParallaxScroll` notification handler is empty | **DELETE** (write `motion/parallax.dart` fresh for onboarding, F3) |
| `CustomPullToRefresh` (`pull_to_refresh_custom.dart`, 30) | Themed `RefreshIndicator` + haptic | home, statistics, profile, transactions, notifications | Haptic awaited before refresh; uses scaffold bg | **KEEP→** `components/neo_pop_refresh.dart` |
| `PulseAnimation` (`pulse_animation.dart`, 58) | Infinite scale loop | 16 sites / 12 screens | Never stops; min/max read only in `initState`; no reduce-motion | **KEEP→** `motion/attention_pulse.dart`, restricted to finite attention cues (e.g. OTP resend, live status). Remove all decorative uses |
| `RippleEffect` (`ripple_effect.dart`, 107) | Custom circle ripple painter + `onTap` | `create_account_screen.dart:376`, `home_screen.dart:276,292`, `my_cards_screen.dart:89`, `profile_screen.dart:198,459` | Always wraps a `null`-handler Material button; no clipping; `shouldRepaint` compares the same animation object | **MERGE** into `motion/pressable.dart` (duplicate press feedback of `CredButtonPress`) |
| `ScalePageRoute` (`scale_page_route.dart`, 38) | Scale 0.8 + fade route | **unused** | | **DELETE** (duplicate of `CredPageTransition`) |
| `SharedElementTransition` (`shared_element_transition.dart`, 35) | `Hero` whose flight spins 360° | **unused** | Unsafe `toHeroContext.widget as Hero` cast | **DELETE** (use plain `Hero` where needed) |
| `ShimmerLoader` (`shimmer_loader.dart`, 30) | Shimmer box | **unused** | Light-theme greys (`Colors.grey[300]`) on a dark app | **DELETE** (duplicate of `SkeletonLoader`) |
| `SkeletonLoader` / `SkeletonCard` / `SkeletonList` (`skeleton_loader_full.dart`, 85) | Dark shimmer boxes, row and list skeletons | home, profile, transfer, statistics, transactions, notifications | Raw hex `0xFF1A1A1A`/`0xFF2A2A2A` (`:21,22,27,44`); one generic row shape for every screen | **KEEP→** `components/skeleton.dart` (token colours, per-screen shapes, reduce-motion = static) |
| `SlidePageRoute` (`slide_page_route.dart`, 56) | Directional slide + fade route | **unused** | | **DELETE** (duplicate of `CredPageTransition`) |
| `SpringAnimation` (`spring_animation.dart`, 84) | Scale 0.85→1 + translate on mount | 12 sites (every primary CTA) | **Not a spring**: `Curves.easeOutCubic` (`:45,53`); damping/stiffness/mass params ignored | **MERGE** into `motion/entrance.dart`; real springs go in `motion/springs.dart` (`SpringSimulation` presets) |
| `StaggeredListAnimation` (`staggered_list_animation.dart`, 32) | Per-index fade + translate | `home_screen.dart:857`, `my_cards_screen.dart:73` | Grows *duration* (not delay) with index; `Opacity` | **MERGE** into `motion/entrance.dart` stagger helper (duplicate of `CredSlideIn`+delay) |
| `SwipeToDismiss` (`swipe_to_dismiss.dart`, 106) | `Dismissible` + post-dismiss fade | transactions, notifications (x2) | Calls `onDismiss` 300 ms+ after `onDismissed`, so the "dismissed Dismissible still in tree" assertion fires; no confirm/undo | **KEEP→** `components/swipe_action_row.dart` (rewrite on `confirmDismiss` + undo snackbar; never on financial records) |
| `CredBottomNavigationBar` (`widgets/cred_bottom_navigation_bar.dart`, 105) | Stock `BottomNavigationBar` + orange icon pill | home, my cards, statistics, profile | Indicator not animated; caller-side routing duplicated 4x | **KEEP→** `components/neo_pop_bottom_nav.dart` + `StatefulShellRoute` shell |
| `NeoPopButton` / `NeoPopPrimaryButton` / `NeoPopSuccessButton` / `NeoPopCard` (`widgets/neopop_button.dart`, 231) | Hard-shadow button with scale + haptic; CTA presets; hard-shadow card | **unused** | Radius 16 and white highlight shadow are not NeoPOP (should be sharp, solid edge faces, face translate on press); `DefaultTextStyle` overridden by child `Text`; no Semantics | **KEEP→** `components/neo_pop_button.dart` and `components/neo_pop_surface.dart` (redesign on top of `motion/pressable.dart`) |
| `NeumorphicContainer` / `NeumorphicButton` (`widgets/neumorphic_container.dart`, 147) | Soft dual-shadow container and press button | **unused** (`NeumorphicButton` uses `NeumorphicContainer` internally) | Neumorphism contradicts NeoPOP | **DELETE** (duplicate of `NeoPopCard`/`NeoPopButton`) |

**Duplicate clusters, summarised**
- **Page routes (4):** `CredPageTransition` (kept), `ScalePageRoute`, `SlidePageRoute` and `SharedElementTransition` (deleted).
- **Fade/slide entrance (9):** `CredSlideIn` (kept as `Entrance`) absorbs `FadeInAnimation`, `DelayedAnimation`, `CredCardReveal`, `SpringAnimation` and `StaggeredListAnimation`. Deleted: `OptimizedAnimation`, `OptimizedListAnimation`, `OptimizedFadeIn` and `CredStaggeredGrid`. The third-party `flutter_staggered_animations` should also be removed from screens.
- **Press feedback (6):** `CredButtonPress` (kept as `Pressable`) absorbs `RippleEffect`. Deleted: `AnimatedButton`, `NeumorphicButton`. `NeoPopButton` is rebuilt on top of `Pressable`.
- **Celebration (2):** `ConfettiEffect` (kept) and `CelebratoryAnimation` (deleted).
- **Skeleton (2):** `SkeletonLoader` (kept) and `ShimmerLoader` (deleted).

**Unused dependencies** surfaced by this audit: `go_router`, `animations`, `lottie`, `flutter_animate`, `animated_text_kit` and `flutter_svg` are declared in `pubspec.yaml` and imported nowhere in `lib/`.

---

## 4. Theme audit: `lib/constants/theme.dart` (362 lines), `lib/main.dart` (85 lines)

### 4.1 Legacy alias colours (`theme.dart:17, 27, 29-50`)
| Alias | Resolves to | Line | Uses outside theme.dart | Note |
|---|---|---|---|---|
| `credNeoPaccha` | `credNeonGreen` | 17 | 12 | |
| `credRed` | `credError` | 27 | 0 | |
| `credBlack` | `credPureBackground` | 30 | 0 | |
| `credCharcoalBlack` | `credPureBackground` | 31 | 0 | |
| `credGray` | `credSurfaceCard` | 32 | 1 (`core/error_handler.dart:32`) | named grey, is near-black |
| `credWhite` | `credPopWhite` | 33 | 41 | |
| `credTextPrimary` | `credPopWhite` | 34 | 56 | |
| `primaryGreen` | `credNeonGreen` | 35 | 3 | |
| `backgroundColor` | `credPureBackground` | 36 | 0 | |
| `textDark` | `credPopWhite` | 37 | 0 | **"dark" is white** |
| `textLight` | `credTextSecondary` | 38 | 0 | |
| `white` | `credPopWhite` | 39 | 0 | |
| `grey` | `credTextTertiary` | 40 | 0 | |
| `lightGrey` | `credMediumGray` | 41 | 0 | |
| `red` | `credError` | 42 | 2 (`transfer_review_screen.dart:156,168`) | |
| `lightRed` | raw `0xFFFF6B8A` | 43 | 0 | |
| `credGreen` | `credNeonGreen` | 44 | 1 (`core/error_handler.dart:21`) | |
| `credOrange` | `credOrangeSunshine` | 45 | 1 (`home_screen.dart:529`) | |
| `credPurple` | `credOrangeSunshine` | 46 | 0 | **purple is orange** |
| `credPurpleLight` | raw `0xFFFFA366` | 47 | 0 | |
| `credPurpleDark` | raw `0xFFE66A00` | 48 | 0 | duplicates gradient stop at `:56` |
| `credBlue` | raw `0xFF007AFF` | 49 | 2 (`login_screen.dart:339`, `home_screen.dart:547`) | iOS system blue, off-palette |
| `darkGreen` | `credNeonGreen` | 50 | 0 | **"dark" is neon** |
| `credPurpleGradient` / `credBlackGradient` / `credOrangeSunshineGradient` | gradient aliases | 84-86 | 0 | |
| `AppTheme.theme` getter | `lightTheme` | 361 | 0 | |

Other theme findings:
- Raw hex in gradient stops: `0xFFE66A00` `:56`, `0xFFB8D600` `:62`, `0xFFCC1A4F` `:68`.
- Unused palette: `credPinkPong`, `credDarkGray`, `credLightGray`, and all gradients except `credOrangeGradient`.
- **No elevation ramp.** `credPureBackground #0D0D0D` vs `credSurfaceCard #0F0F0F` is about 1.02:1.
- `lightTheme` returns `Brightness.dark` (`:124-127`), so the name is wrong. `fontFamily: 'Inter'` (`:130` and every text style) is **not bundled** in `pubspec.yaml`, so it falls back to Roboto or SF.
- The theme's `textTheme` (`:144-226`) specifies w900. Screens never read it and use w700/w800 inline.
- `neopopHardShadow` (`:89-119`) produces a dark offset plus a white 5 % highlight, which is closer to neumorphism than NeoPOP's solid edge faces. It is used only by the unused `neopop_button.dart`.
- 109 `withOpacity` calls app-wide (deprecated in favour of `withValues` on current Flutter).

### 4.2 `main.dart` issues
- **`darkTheme: AppTheme.lightTheme`** (`main.dart:70`, with `theme:` also `lightTheme` at `:69` and `themeMode: ThemeMode.dark` at `:71`). There is no real dark `ThemeData`. Planned fix: F1 "real dark theme".
- **Forced `TextScaler.linear(1)`** in `MaterialApp.builder` (`main.dart:74-81`). This disables the user's font-size setting app-wide (WCAG 1.4.4). Remove it, and clamp per-component if needed, e.g. `MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3)` on the balance odometer.
- `initialRoute: '/'` (`:72`) always shows Welcome. There is no auth-aware redirect.
- `onGenerateRoute` (`app_router.dart`) uses `MaterialPageRoute` for `/` and unknown routes (`:25, :72`) but the custom transition everywhere else. Route arguments are untyped `Map<String, dynamic>` with invented defaults (`:45-60`).

---

## 5. Target state (per screen)

**Global:**
- One `lib/design_system/`: tokens (colour ramp with at least 3 distinct surfaces, 4 pt spacing, radius 0/2 for NeoPOP, type scale), `NeoPopButton` (solid edge faces, face-translate plunk with spring, haptic, Semantics), `NeoPopSurface`, `NeoPopTextField`, `Pressable`, `Entrance` (one stagger system, capped at about 6 items), `AnimatedAmount`, `Skeleton`, and `EmptyState`/`ErrorState`.
- Respect `MediaQuery.disableAnimations` everywhere. Remove all infinite pulses. Restore text scaling.
- Primary text on accent fills is dark (`#0D0D0D` on orange or neon) for at least 4.5:1.

| Screen | Target |
|---|---|
| Welcome | Real splash: brand mark built from tokens with a one-shot reveal, then an auth-aware redirect (go_router). One NeoPOP primary CTA, no pulse. |
| Onboarding | Parallax illustrations driven by `PageController` (F3), one "Skip" at top, CTA becomes "Get started" on the last page. Custom NeoPOP progress indicator. Reduce-motion swaps parallax for a crossfade. |
| Login | `NeoPopTextField` with inline validation (`Validators`), autofill hints, an in-button loading state and a shake on error. No demo credentials in UI (move to a debug-only banner). Biometric login as a real toggle or button via `local_auth`. |
| Create account | Same field primitives, password-strength meter, tappable Terms link. No password in route arguments. Only social buttons that actually work, or none. |
| Verification / OTP | `SafeArea` + scroll. Single hidden field with `AutofillHints.oneTimeCode` driving 4 to 6 NeoPOP cells (paste support). 30 s resend countdown. Error shake plus red cells. Success tick only after a valid code. |
| Forgot password | Selectable recovery-method cards (radio semantics), email or phone input, then sending, "check your inbox" and error states. |
| Fingerprint setup | `local_auth` flow with scanning, success and failure animation states, a "Not now" secondary action and an "unavailable" fallback. |
| Home | Dark collapsing balance header (`SliverAppBar`) with `AnimatedAmount` odometer and hide-balance toggle. Quick actions as a NeoPOP tile row with no pulses. Real error and empty states. Per-section `BlocBuilder`/`BlocSelector`. Transaction rows open details. |
| My cards | Card stack with drag-to-flip (correct back face), tilt and sheen. CVV masked with reveal-on-hold. Details for the focused card. `CardBloc`-driven loading, empty and error states. Inside the tab shell, with no back arrow. |
| Add card | Live preview bound to controllers with brand detection, card-number grouping, Luhn check, MM/YY mask and CVV limit. Preview flips to the back when CVV is focused. Save button with an in-flight state. |
| Transfer | Single input path: a custom keypad only (field is read-only and focusable for a11y) with rolling-digit amount, 2-decimal and max-length guards, and inline over-balance warning. Recipient carousel with search plus an "add" flow. Selection via `ValueNotifier` instead of whole-screen `setState`. |
| Transfer review | Real sender, real fee and real reference input. Swipe-to-pay `NeoPopSlider` with an optional PIN or biometric step, disabled while in flight. Idempotent submit. Failure sheet with retry. |
| Transfer success | No back arrow (`pushNamedAndRemoveUntil` or `go`). Correct copy and recipient initials. One-shot brand-coloured burst plus check morph (static under reduce-motion). Count-up that starts when visible. Share-receipt and transaction ID. Live-region announcement. |
| Transactions | Date-grouped `SliverList.builder` with sticky headers, debounced search, working filter sheet and capped entrance stagger. No swipe-to-delete on ledger entries. Refreshable empty and error states. |
| Statistics | Real chart from transaction data (period selector Week/Month/Year) with animated bars or lines and a semantic summary. Income vs expense cards. Fix the int/double totals. Correct title. |
| Notifications | All notifications, grouped Today / Yesterday / Earlier. Unread dot and mark-as-read. Per-type icon colour from tokens. One entrance system. No-results state. Swipe-to-archive with undo. |
| Profile | NeoPOP settings list with real destinations (or hidden until implemented). Edit-profile sheet with validation and saving state. Logout through a single confirmed path with a destructive-styled NeoPOP button. Placeholder URL removed. |
| Bottom nav | `StatefulShellRoute` (or `IndexedStack`) shell that preserves tab state. NeoPOP bar with a spring-animated indicator, notification badge and scroll-to-top on re-tap. No back arrows on tab roots. |
