# FinPay 💸

Sup everyone! 👋 This is my first proper Flutter app. I built this while learning how to code mobile apps. I really liked how CRED looks so I tried to copy their design style (dark mode + smooth animations).

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

**Login details:**
Email: `user@finpay.com`
Pass: `FinPay123`

(Just use these defaults, I haven't made a working sign up screen yet lol)

## Note
This is just for learning purposes. If you see some bad code or weird practices, let me know! I'm still learning best practices.

Thanks for checking it out! 🚀
