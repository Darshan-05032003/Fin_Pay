import '../di/service_locator.dart';
import '../../services/database_service.dart';
import '../../data/datasources/local_datasource.dart';
import '../../data/datasources/local_datasource_impl.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/user_repository_impl.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/repositories/transaction_repository_impl.dart';
import '../../domain/usecases/get_user_usecase.dart';
import '../../domain/usecases/update_user_usecase.dart';
import '../../domain/usecases/authenticate_user_usecase.dart';
import '../../domain/usecases/get_transactions_usecase.dart';
import '../../domain/usecases/add_transaction_usecase.dart';
import '../../core/logger.dart';

/// Dependency Injection setup
/// 
/// This class initializes all dependencies following the Dependency Injection pattern.
/// It provides a centralized place to configure all services, repositories, and use cases.
class DependencyInjection {
  static final ServiceLocator _locator = ServiceLocator();

  /// Initialize all dependencies
  static Future<void> init() async {
    Logger.info('Initializing dependencies...');

    // Core services
    _locator.registerSingleton<DatabaseService>(DatabaseService());
    
    // Data sources
    _locator.registerLazySingleton<LocalDataSource>(
      () => LocalDataSourceImpl(_locator.get<DatabaseService>()),
    );

    // Repositories
    _locator.registerLazySingleton<IUserRepository>(
      () => UserRepositoryImpl(_locator.get<LocalDataSource>()),
    );

    _locator.registerLazySingleton<ITransactionRepository>(
      () => TransactionRepositoryImpl(_locator.get<LocalDataSource>()),
    );

    // Use cases
    _locator.registerLazySingleton<GetUserUseCase>(
      () => GetUserUseCase(_locator.get<IUserRepository>()),
    );

    _locator.registerLazySingleton<UpdateUserUseCase>(
      () => UpdateUserUseCase(_locator.get<IUserRepository>()),
    );

    _locator.registerLazySingleton<AuthenticateUserUseCase>(
      () => AuthenticateUserUseCase(_locator.get<IUserRepository>()),
    );

    _locator.registerLazySingleton<GetTransactionsUseCase>(
      () => GetTransactionsUseCase(_locator.get<ITransactionRepository>()),
    );

    _locator.registerLazySingleton<AddTransactionUseCase>(
      () => AddTransactionUseCase(
        _locator.get<ITransactionRepository>(),
        _locator.get<IUserRepository>(),
      ),
    );

    Logger.info('Dependencies initialized successfully');
  }

  /// Get a service from the locator
  static T get<T>() => _locator.get<T>();

  /// Reset all dependencies (useful for testing)
  static void reset() {
    _locator.reset();
  }
}

