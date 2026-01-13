# FinPay 💰 - My First Flutter Financial App

Hey there! 👋 This is **FinPay** - a financial payment app I built while learning Flutter development. I wanted to create something that looks and feels professional, so I took inspiration from CRED's beautiful design and tried to implement similar smooth animations and a modern UI.

## About This Project

I'm relatively new to Flutter and mobile development, but I wanted to challenge myself by building a complete app from scratch. This project helped me learn a lot about:
- State management (I migrated from Provider to BLoC - more on that below!)
- Clean Architecture principles
- Working with local databases (SQLite)
- Creating smooth animations
- Building a production-ready app structure

It's not perfect, but I'm proud of what I've built and excited to keep improving it! 🚀

## What Can This App Do?

- 💳 **Send Money**: Transfer money to contacts with a beautiful UI
- 📊 **Track Expenses**: See your spending analytics and transaction history
- 🔔 **Notifications**: Get notified about your transactions
- 💳 **Manage Cards**: Add and manage your payment cards
- 🎨 **Beautiful Design**: Dark theme with smooth animations (inspired by CRED)
- 💾 **Offline First**: Everything is stored locally using SQLite

## Try It Out!

**Default Login:**
- Email: `user@finpay.com`
- Password: `FinPay123`

## Getting Started

If you want to run this on your machine:

### Prerequisites

- Make sure you have Flutter installed on your system
- Have Git installed (for cloning the repository)
- An IDE like VS Code or Android Studio with Flutter extensions

### Clone the Repository

First, you need to clone this repository to your local machine. 

**Option 1: Using Git Clone (Recommended)**

Open your terminal (or command prompt) and run one of these commands:

**Using HTTPS (Recommended for beginners):**
```bash
git clone https://github.com/YOUR_USERNAME/fin_pay.git
```

**Or using SSH (if you have SSH keys set up):**
```bash
git clone git@github.com:YOUR_USERNAME/fin_pay.git
```

**Note:** Replace `YOUR_USERNAME` with your actual GitHub username. If you're cloning someone else's repository, use their GitHub username instead.

After cloning, navigate into the project directory:
```bash
cd fin_pay
```

**Option 2: Download as ZIP**

If you prefer not to use Git, you can also:
1. Click the green "Code" button on GitHub
2. Select "Download ZIP"
3. Extract the ZIP file to your desired location
4. Open the extracted folder in your terminal and continue with the next steps

### Install Dependencies

Now install all the required packages:
```bash
flutter pub get
```

### Run the App

Make sure you have a device connected (physical device or emulator), then run:
```bash
flutter run
```

**That's it!** The app should launch on your device/emulator. 🎉

**Tip:** If you're new to Flutter, make sure you've run `flutter doctor` first to check if everything is set up correctly!

## Project Structure

I organized the code following Clean Architecture principles (something I learned about recently!). Here's how I structured everything:

```
lib/
├── blocs/              # State management using BLoC pattern
│   ├── user/          # User-related state
│   ├── transaction/   # Transaction state
│   ├── card/          # Card management state
│   └── notification/  # Notification state
├── screens/            # All the UI screens
├── widgets/           # Reusable components
├── models/            # Data models
├── services/          # Business logic
├── repositories/      # Data access layer
└── core/              # Core utilities and configs
```

## My Learning Journey: State Management

When I started this project, I was using **Provider** for state management because it seemed simpler. But as I learned more and wanted to make this project more professional (and resume-worthy!), I decided to migrate everything to **BLoC**.

### Why BLoC?

BLoC (Business Logic Component) is a pattern that separates your business logic from your UI. It took me some time to understand, but now I really like it because:

- **Predictable**: All state changes happen through events - you always know what's changing
- **Testable**: You can test your business logic separately from UI
- **Scalable**: As the app grows, it's easier to manage state
- **Industry Standard**: Many companies use BLoC, so it's great for learning

### How BLoC Works (In Simple Terms)

Think of BLoC like this:
1. **Events** = Things that happen (user clicks a button, data needs to load)
2. **States** = How things are right now (loading, loaded, error)
3. **BLoC** = The brain that decides what state to show based on events

Here's a simple example:

```dart
// When user clicks "Load Profile", we dispatch an event
context.read<UserBloc>().add(const LoadUserEvent());

// The UI listens to state changes
BlocBuilder<UserBloc, UserState>(
  builder: (context, state) {
    if (state is UserLoading) {
      return CircularProgressIndicator(); // Show loading
    }
    if (state is UserLoaded) {
      return Text('Welcome ${state.userName}'); // Show user
    }
    return Text('Error occurred'); // Show error
  },
)
```

It was confusing at first, but now I find it really clean and organized!

## Architecture & Patterns I Used

I tried to follow best practices I learned from tutorials and documentation:

- **Clean Architecture**: Separated code into layers (presentation, domain, data)
- **BLoC Pattern**: For state management
- **Repository Pattern**: To abstract data access
- **Dependency Injection**: To manage dependencies cleanly
- **Result Pattern**: For error handling without throwing exceptions

I'm still learning, so if you see something that could be improved, feel free to let me know!

## Features I'm Proud Of

- ✨ **Smooth Animations**: I spent a lot of time on these! Card flips, parallax effects, particle animations
- 🎨 **Beautiful UI**: Dark theme with purple/orange accents
- 💾 **Local Database**: Everything persists using SQLite
- 🔄 **State Management**: Fully migrated to BLoC
- 📱 **Responsive**: Works well on different screen sizes
- 🎯 **Error Handling**: Proper error handling and user feedback
- 🔔 **Haptic Feedback**: Makes interactions feel more real

## What I Learned

This project taught me so much:
- How to structure a Flutter app properly
- State management patterns (Provider → BLoC migration)
- Working with databases
- Creating custom animations
- Clean code principles
- Git and version control

I'm still learning and improving, but this project represents a lot of hours of learning, debugging, and building!

## Technologies & Packages Used

- **Flutter** - The framework
- **flutter_bloc** - State management
- **sqflite** - Local database
- **go_router** - Navigation
- And many more for animations, UI, etc.

## Future Improvements

Things I want to add/improve:
- [ ] Connect to a real backend API
- [ ] Add more comprehensive tests
- [ ] Improve error messages
- [ ] Add more features (maybe budgeting?)
- [ ] Performance optimizations
- [ ] Better documentation

## Note

This is a learning project I built to practice Flutter development and showcase my skills. It's not a real financial app - please don't use it for actual money management! 😅

## License

This project is for educational purposes. Feel free to learn from it, but please don't use it commercially without proper modifications and security audits.

---

**Thanks for checking out my project!** 🙏

If you're also learning Flutter, I hope this helps you understand how to structure a real-world app. If you have suggestions or feedback, I'd love to hear them!

Happy coding! 💻✨
