import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/platform/biometric_authenticator.dart';
import 'package:fin_pay/core/platform/flutter_haptic_service.dart';
import 'package:fin_pay/core/platform/flutter_secure_storage_adapter.dart';
import 'package:fin_pay/core/platform/motion_sensor.dart';
import 'package:fin_pay/core/platform/screen_protector.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/core/settings/settings_repository.dart';
import 'package:fin_pay/core/storage/secure_storage.dart';
import 'package:fin_pay/data/database/app_database.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/data/datasources/sqflite_local_datasource.dart';
import 'package:fin_pay/data/repositories/auth_repository_impl.dart';
import 'package:fin_pay/data/repositories/card_repository_impl.dart';
import 'package:fin_pay/data/repositories/notification_repository_impl.dart';
import 'package:fin_pay/data/repositories/transaction_repository_impl.dart';
import 'package:fin_pay/data/repositories/user_repository_impl.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/domain/repositories/notification_repository.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/domain/usecases/add_transaction_usecase.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:fin_pay/domain/usecases/get_transactions_usecase.dart';
import 'package:fin_pay/domain/usecases/get_user_usecase.dart';
import 'package:fin_pay/domain/usecases/update_user_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart' show DatabaseFactory, databaseFactory;

/// The service locator. Hand-written registrations (no code generation).
final GetIt sl = GetIt.instance;

/// Replacements for platform-backed services, used by tests and the widget
/// gallery. Anything left null gets the production implementation.
class DiOverrides {
  const DiOverrides({
    this.haptics,
    this.biometrics,
    this.motionSensor,
    this.screenProtector,
    this.secureStorage,
    this.settingsRepository,
    this.databaseFactory,
    this.databasePath,
    this.clock,
    this.authRepository,
  });

  final HapticService? haptics;
  final BiometricAuthenticator? biometrics;
  final MotionSensor? motionSensor;
  final ScreenProtector? screenProtector;
  final SecureStorage? secureStorage;
  final SettingsRepository? settingsRepository;
  final DatabaseFactory? databaseFactory;
  final String? databasePath;
  final Clock? clock;

  /// Replaces the credential/session repository (widget tests).
  final AuthRepository? authRepository;
}

/// Registers every dependency. Call once at start-up (or per test with
/// [overrides] after [reset]).
Future<void> init({DiOverrides overrides = const DiOverrides()}) async {
  // Platform
  sl
    ..registerLazySingleton<Clock>(() => overrides.clock ?? const Clock())
    ..registerLazySingleton<SecureStorage>(
      () => overrides.secureStorage ?? FlutterSecureStorageAdapter(),
    )
    ..registerLazySingleton<SettingsRepository>(
      () =>
          overrides.settingsRepository ?? SharedPreferencesSettingsRepository(),
    )
    ..registerLazySingleton<SettingsCubit>(() => SettingsCubit(sl()))
    ..registerLazySingleton<HapticService>(
      () =>
          overrides.haptics ??
          FlutterHapticService(
            isEnabled: () => sl<SettingsCubit>().state.hapticsEnabled,
          ),
    )
    ..registerLazySingleton<BiometricAuthenticator>(
      () => overrides.biometrics ?? LocalAuthBiometricAuthenticator(),
    )
    ..registerLazySingleton<MotionSensor>(
      () => overrides.motionSensor ?? SensorsPlusMotionSensor(),
    )
    ..registerLazySingleton<ScreenProtector>(
      () => overrides.screenProtector ?? MethodChannelScreenProtector(),
    );

  // Database
  final dbPath = overrides.databasePath ?? await AppDatabase.defaultPath();
  sl
    ..registerLazySingleton<AppDatabase>(
      () => AppDatabase(
        factory: overrides.databaseFactory ?? databaseFactory,
        path: dbPath,
        clock: sl(),
      ),
    )
    ..registerLazySingleton<LocalDataSource>(
      () => SqfliteLocalDataSource(sl()),
    );

  // Repositories
  sl
    ..registerLazySingleton<IUserRepository>(() => UserRepositoryImpl(sl()))
    ..registerLazySingleton<ITransactionRepository>(
      () => TransactionRepositoryImpl(sl()),
    )
    ..registerLazySingleton<ICardRepository>(
      () => CardRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton<INotificationRepository>(
      () => NotificationRepositoryImpl(sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () =>
          overrides.authRepository ??
          AuthRepositoryImpl(storage: sl(), users: sl(), clock: sl()),
    );

  // Use cases
  sl
    ..registerLazySingleton(() => GetUserUseCase(sl()))
    ..registerLazySingleton(() => UpdateUserUseCase(sl()))
    ..registerLazySingleton(() => AuthenticateUserUseCase(sl()))
    ..registerLazySingleton(() => GetTransactionsUseCase(sl()))
    ..registerLazySingleton(() => AddTransactionUseCase(sl()));

  // Blocs
  sl
    ..registerLazySingleton<SessionCubit>(
      () => SessionCubit(authenticate: sl(), authRepository: sl()),
    )
    ..registerFactory(
      () => UserBloc(getUserUseCase: sl(), updateUserUseCase: sl()),
    )
    ..registerFactory(
      () => TransactionBloc(
        getTransactionsUseCase: sl(),
        addTransactionUseCase: sl(),
        transactionRepository: sl(),
      ),
    )
    ..registerFactory(() => CardBloc(repository: sl()))
    ..registerFactory(() => NotificationBloc(repository: sl()));
}

/// Drops every registration (tests call this in `tearDown`).
Future<void> reset() => sl.reset();
