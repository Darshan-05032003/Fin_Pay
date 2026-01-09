# FinPay - Financial Payment App

A production-ready Flutter application for financial payments with CRED-like design and animations.

## Features

- 💳 **Payment Management**: Send money, pay bills, manage cards
- 📊 **Statistics**: View spending analytics and transaction history
- 🔔 **Notifications**: Real-time notifications for transactions
- 🎨 **CRED-like Design**: Dark theme with purple accents and smooth animations
- 💾 **Local Database**: SQLite for data persistence
- 🔄 **State Management**: Provider for app-level state
- ✨ **Advanced Animations**: 3D card flips, parallax scrolling, particle effects, and more

## Project Structure

```
lib/
├── core/                    # Core functionality
│   ├── app_config.dart      # App configuration
│   ├── error_handler.dart   # Error handling
│   ├── exception_handler.dart # Exception handling
│   ├── logger.dart          # Logging utility
│   ├── network_service.dart # API service (ready for backend)
│   └── route_guard.dart    # Route authentication guard
├── constants/               # App constants
│   └── theme.dart          # Theme configuration
├── models/                  # Data models
│   ├── user.dart
│   ├── transaction.dart
│   ├── card.dart
│   └── notification_item.dart
├── providers/               # State management
│   ├── user_provider.dart
│   ├── transaction_provider.dart
│   ├── card_provider.dart
│   └── notification_provider.dart
├── repositories/            # Data repositories
│   ├── user_repository.dart
│   └── transaction_repository.dart
├── routes/                  # Navigation
│   └── app_router.dart
├── screens/                 # UI screens
│   ├── auth/               # Authentication screens
│   ├── home/               # Home dashboard
│   ├── cards/              # Card management
│   ├── transfer/           # Money transfer
│   ├── transactions/       # Transaction history
│   ├── statistics/         # Analytics
│   ├── profile/            # User profile
│   └── notifications/      # Notifications
├── services/                # Business logic
│   ├── database_service.dart # SQLite database
│   ├── user_service.dart   # User operations
│   └── haptic_service.dart # Haptic feedback
├── utils/                   # Utilities
│   ├── constants.dart      # App constants
│   ├── helpers.dart        # Helper functions
│   └── validators.dart     # Input validation
└── widgets/                 # Reusable widgets
    └── animations/         # Animation widgets
```

## Default Login Credentials

- **Email**: `user@finpay.com`
- **Password**: `FinPay123`

## Getting Started

1. Install dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```

## Architecture

FinPay follows **Clean Architecture** principles with clear separation of concerns:

- **Presentation Layer**: Screens, widgets, and state management (Provider)
- **Domain Layer**: Business logic (Use Cases) and repository interfaces
- **Data Layer**: Data sources and repository implementations
- **Core Layer**: Dependency injection, error handling, utilities

### Key Patterns

- **Dependency Injection**: Service Locator pattern for managing dependencies
- **Repository Pattern**: Abstract data access with interfaces
- **Use Case Pattern**: Encapsulate business logic
- **Result Pattern**: Functional error handling without exceptions

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.
See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for implementation guidelines.

## Production Features

- ✅ Error handling and logging
- ✅ Input validation
- ✅ Route guards
- ✅ Repository pattern
- ✅ Network service (ready for API integration)
- ✅ Exception handling
- ✅ Performance optimizations
- ✅ Responsive design
- ✅ Haptic feedback
- ✅ Pull-to-refresh
- ✅ Skeleton loaders

## Animation Features

- 3D card flip/reveal
- Parallax scrolling
- Particle effects (confetti)
- Haptic feedback
- Advanced gesture animations
- Skeleton loaders with shimmer
- Icon morphing
- Custom pull-to-refresh
- Spring physics animations
- Celebratory animations
- Micro-interactions

## License

This project is for educational purposes.
