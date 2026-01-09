/// Dependency Injection Container
/// 
/// This service locator provides a centralized way to manage dependencies
/// following the Service Locator pattern. It supports lazy initialization
/// and singleton instances.
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  final Map<Type, dynamic> _services = {};
  final Map<Type, dynamic Function()> _factories = {};

  /// Register a singleton instance
  void registerSingleton<T>(T instance) {
    _services[T] = instance;
  }

  /// Register a factory function for lazy initialization
  void registerFactory<T>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Register a lazy singleton (created on first access)
  void registerLazySingleton<T>(T Function() factory) {
    _factories[T] = () {
      if (!_services.containsKey(T)) {
        _services[T] = factory();
      }
      return _services[T];
    };
  }

  /// Get a registered service
  T get<T>() {
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    if (_factories.containsKey(T)) {
      final instance = _factories[T]!() as T;
      if (!_services.containsKey(T)) {
        _services[T] = instance;
      }
      return instance;
    }
    throw Exception('Service of type $T is not registered');
  }

  /// Check if a service is registered
  bool isRegistered<T>() {
    return _services.containsKey(T) || _factories.containsKey(T);
  }

  /// Reset all registered services (useful for testing)
  void reset() {
    _services.clear();
    _factories.clear();
  }
}

