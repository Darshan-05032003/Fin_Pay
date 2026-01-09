# FinPay - Implementation Guide

## Architecture Overview

This application follows **Clean Architecture** principles with clear separation of concerns:

```
┌─────────────────────────────────────┐
│      Presentation Layer             │
│  (Screens, Widgets, Providers)    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│        Domain Layer                  │
│  (Use Cases, Repository Interfaces) │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│         Data Layer                   │
│  (Data Sources, Repository Impl)  │
└─────────────────────────────────────┘
```

## Key Components

### 1. Dependency Injection
- **Location**: `lib/core/di/`
- **Usage**: All dependencies registered in `DependencyInjection.init()`
- **Pattern**: Service Locator

### 2. Result Pattern
- **Location**: `lib/core/result/result.dart`
- **Purpose**: Functional error handling
- **Usage**: All repository methods return `Result<T>`

### 3. Use Cases
- **Location**: `lib/domain/usecases/`
- **Naming**: `VerbNounUseCase` (e.g., `GetUserUseCase`)
- **Purpose**: Encapsulate business logic

### 4. Repositories
- **Interfaces**: `lib/domain/repositories/`
- **Implementations**: `lib/domain/repositories/*_impl.dart`
- **Purpose**: Abstract data access

## Adding a New Feature

### Step 1: Define Repository Interface
```dart
// lib/domain/repositories/feature_repository.dart
abstract class IFeatureRepository {
  Future<Result<Feature>> getFeature();
}
```

### Step 2: Implement Repository
```dart
// lib/domain/repositories/feature_repository_impl.dart
class FeatureRepositoryImpl implements IFeatureRepository {
  final LocalDataSource _dataSource;
  
  FeatureRepositoryImpl(this._dataSource);
  
  @override
  Future<Result<Feature>> getFeature() async {
    // Implementation
  }
}
```

### Step 3: Create Use Case
```dart
// lib/domain/usecases/get_feature_usecase.dart
class GetFeatureUseCase {
  final IFeatureRepository _repository;
  
  GetFeatureUseCase(this._repository);
  
  Future<Result<Feature>> call() async {
    return await _repository.getFeature();
  }
}
```

### Step 4: Register in DI
```dart
// lib/core/di/dependency_injection.dart
_locator.registerLazySingleton<IFeatureRepository>(
  () => FeatureRepositoryImpl(_locator.get<LocalDataSource>()),
);

_locator.registerLazySingleton<GetFeatureUseCase>(
  () => GetFeatureUseCase(_locator.get<IFeatureRepository>()),
);
```

### Step 5: Create Provider
```dart
// lib/presentation/providers/feature_provider.dart
class FeatureProvider with ChangeNotifier {
  final GetFeatureUseCase _getFeatureUseCase;
  
  FeatureProvider() : _getFeatureUseCase = DependencyInjection.get<GetFeatureUseCase>();
  
  Future<void> loadFeature() async {
    final result = await _getFeatureUseCase();
    result.onSuccess((feature) {
      // Handle success
    }).onFailure((message, error) {
      // Handle error
    });
  }
}
```

## Best Practices

1. **Always use Result pattern** for error handling
2. **Keep use cases focused** - one responsibility per use case
3. **Depend on interfaces**, not implementations
4. **Register all dependencies** in DependencyInjection
5. **Use async/await** properly with Result pattern
6. **Log important operations** using Logger
7. **Handle errors gracefully** in providers

## Testing

- **Unit Tests**: Test use cases and repositories in isolation
- **Widget Tests**: Test UI components
- **Integration Tests**: Test full flows

## Migration Notes

- Old providers in `lib/providers/` are being migrated to `lib/presentation/providers/`
- Old services are being replaced with use cases
- All new code should follow the new architecture

