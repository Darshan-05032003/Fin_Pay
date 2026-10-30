# FinPay 💸

Sup everyone! 👋 This is my first proper Flutter app. I built this while learning how to code mobile apps. I really liked how CRED looks so I tried to copy their design style (dark mode + smooth animations). FinPay is inspired by CRED's NeoPOP design language; it is not affiliated with CRED.

## What it does
- You can "send" money to people (fake money, don't worry)
- Check your expenses with some cool charts
- Manage your cards
- It works offline! (everything is saved on your phone)

## Tech stuff I used
I'm trying to follow "Clean Architecture" so the folders are kinda deep. I hope I organized it right!
- **Flutter** (obviously)
- **BLoC** - I was using Provider before but migrated to BLoC because everyone says it's better for jobs. It's kinda boilerplate-y but keeps things organized.
- **GoRouter** - for navigation
- **Sqflite** - for the database
- **GetIt** - just added this for dependency injection to clean up my messy main file.
- **Validations** - I also added `very_good_analysis` to make sure my code isn't total garbage.

## Tests
I actually wrote some unit tests! 🎉
Run `flutter test` to see them pass.

## How to run it
1. clone the repo
2. run `flutter pub get`
3. run `flutter run`

**Login details (demo account):**
Email: `user@finpay.com`
Pass: `FinPay123`

**Sign-up (simulated):** create an account with any name, email, 10-digit Indian mobile number and an 8+ character password. The verification code is simulated locally: it is the **last six digits of the mobile number you entered** (no SMS is sent). Sign-up re-keys the single on-device demo account; the opening balance stays. Biometrics and the password-reset email are simulated too.

The password is not stored anywhere in the app code: `lib/core/auth/demo_credentials.dart` holds a precomputed PBKDF2-HMAC-SHA256 `(salt, hash)` pair that is seeded into secure storage on first run, and a test fails if the plaintext ever shows up under `lib/`. After 5 wrong attempts the account locks for 30 seconds.

## Release build
```
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```
R8 minify/shrink is on in `android/app/build.gradle.kts`; `--obfuscate` hides Dart symbols and `--split-debug-info` keeps the symbol files out of the APK (keep `build/symbols` to symbolicate crash reports). Logging is compiled out in release.

## Tests
```
flutter test                     # unit + widget
flutter test --coverage          # writes coverage/lcov.info
flutter test --tags stress --dart-define=FINPAY_STRESS=true --concurrency=1 test/stress
```

## Note
This is just for learning purposes. If you see some bad code or weird practices, let me know! I'm still learning best practices.

Thanks for checking it out! 🚀
