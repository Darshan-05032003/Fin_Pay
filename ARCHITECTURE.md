# FinPay - Architecture Documentation

## Overview

FinPay follows **Clean Architecture** principles with clear separation of concerns, dependency injection, and testable code structure.

## Architecture Layers

### 1. Presentation Layer (`lib/presentation/`)
- **Providers**: State management using Provider pattern
- **Screens**: UI components and screens
- **Widgets**: Reusable UI components

### 2. Domain Layer (`lib/domain/`)
- **Use Cases**: Business logic and application rules
- **Repositories (Interfaces)**: Abstract contracts for data operations
- **Models**: Domain entities

### 3. Data Layer (`lib/data/`)
- **Data Sources**: Concrete implementations of data access
- **Repository Implementations**: Concrete repository implementations
- **Models**: Data transfer objects (DTOs)

### 4. Core Layer (`lib/core/`)
- **DI**: Dependency injection container
- **Result**: Functional error handling
- **Errors**: Exception classes
- **Logger**: Logging utilities
- **Config**: App configuration

## Dependency Flow

```
Presentation → Domain ← Data
     ↓           ↓        ↓
   Use Cases  Interfaces  Data Sources
```

**Rule**: Dependencies always point inward. Outer layers depend on inner layers, never the reverse.

## Key Patterns

### 1. Dependency Injection
- **Service Locator Pattern**: Centralized dependency management
- **Location**: `lib/core/di/`
- **Usage**: All dependencies registered in `DependencyInjection.init()`

### 2. Repository Pattern
- **Interfaces**: Defined in `lib/domain/repositories/`
- **Implementations**: In `lib/domain/repositories/` (impl files)
- **Purpose**: Abstract data access, enable testing, swap implementations

### 3. Use Case Pattern
- **Location**: `lib/domain/usecases/`
- **Purpose**: Encapsulate business logic
- **Naming**: `VerbNounUseCase` (e.g., `GetUserUseCase`)

### 4. Result Pattern
- **Location**: `lib/core/result/result.dart`
- **Purpose**: Functional error handling without exceptions
- **Usage**: All repository and use case methods return `Result<T>`

## Project Structure

```
lib/
├── core/                    # Core functionality
│   ├── di/                  # Dependency injection
│   │   ├── service_locator.dart
│   │   └── dependency_injection.dart
│   ├── result/              # Result pattern
│   │   └── result.dart
│   ├── errors/              # Exception classes
│   │   └── app_exception.dart
│   ├── logger.dart
│   ├── error_handler.dart
│   └── app_config.dart
│
├── domain/                  # Business logic layer
│   ├── repositories/        # Repository interfaces
│   │   ├── user_repository.dart
│   │   └── transaction_repository.dart
│   └── usecases/           # Use cases
│       ├── get_user_usecase.dart
│       ├── update_user_usecase.dart
│       └── authenticate_user_usecase.dart
│
├── data/                    # Data layer
│   └── datasources/        # Data source implementations
│       ├── local_datasource.dart
│       └── local_datasource_impl.dart
│
├── presentation/            # Presentation layer
│   └── providers/          # State management
│       ├── user_provider.dart
│       └── transaction_provider.dart
│
├── models/                  # Data models
├── services/               # Services (legacy, being migrated)
├── routes/                  # Navigation
├── screens/                 # UI screens
├── widgets/                 # Reusable widgets
└── utils/                   # Utilities
```

## Data Flow

1. **User Action** → Screen calls Provider method
2. **Provider** → Calls Use Case
3. **Use Case** → Calls Repository interface
4. **Repository** → Calls Data Source
5. **Data Source** → Accesses database/API
6. **Result** → Flows back through layers
7. **Provider** → Updates state, notifies listeners
8. **Screen** → Rebuilds with new data

## Error Handling

- **Result Pattern**: All operations return `Result<T>`
- **Success**: `Success<T>(data)`
- **Failure**: `Failure<T>(message, error)`
- **Usage**: Chain operations with `flatMap`, handle with `onSuccess`/`onFailure`

## Testing Strategy

- **Unit Tests**: Use cases, repositories, data sources
- **Widget Tests**: UI components
- **Integration Tests**: Full flows
- **Mocking**: Use interfaces for easy mocking

## Best Practices

1. **Single Responsibility**: Each class has one reason to change
2. **Dependency Inversion**: Depend on abstractions, not concretions
3. **Open/Closed**: Open for extension, closed for modification
4. **Interface Segregation**: Small, focused interfaces
5. **Don't Repeat Yourself**: Reuse code through composition

## Migration Path

Current code is being migrated to this architecture:
- ✅ Core DI setup
- ✅ Result pattern
- ✅ Repository interfaces
- ✅ Use cases
- ✅ Updated providers
- 🔄 Migrating remaining providers
- 🔄 Migrating services to use cases

## Future Enhancements

- [ ] Add remote data source for API calls
- [ ] Implement caching strategy
- [ ] Add offline support
- [ ] Implement proper authentication flow
- [ ] Add comprehensive error recovery
- [ ] Add analytics and monitoring
- [ ] Implement proper logging levels

