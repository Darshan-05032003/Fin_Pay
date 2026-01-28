import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/data/datasources/local_datasource.dart';
import 'package:fin_pay/data/datasources/local_datasource_impl.dart';
import 'package:fin_pay/data/repositories/transaction_repository_impl.dart';
import 'package:fin_pay/data/repositories/user_repository_impl.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/domain/usecases/add_transaction_usecase.dart';
import 'package:fin_pay/domain/usecases/authenticate_user_usecase.dart';
import 'package:fin_pay/domain/usecases/get_transactions_usecase.dart';
import 'package:fin_pay/domain/usecases/get_user_usecase.dart';
import 'package:fin_pay/domain/usecases/update_user_usecase.dart';
import 'package:fin_pay/services/database_service.dart';
import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  // Blocs
  sl.registerFactory(
    () => UserBloc(
      getUserUseCase: sl(),
      updateUserUseCase: sl(),
      authenticateUserUseCase: sl(),
    ),
  );
  sl.registerFactory(
    () => TransactionBloc(
      getTransactionsUseCase: sl(),
      addTransactionUseCase: sl(),
    ),
  );
  sl.registerFactory(() => CardBloc(db: sl()));
  sl.registerFactory(() => NotificationBloc(db: sl()));

  // Use cases
  sl.registerLazySingleton(() => GetUserUseCase(sl()));
  sl.registerLazySingleton(() => UpdateUserUseCase(sl()));
  sl.registerLazySingleton(() => AuthenticateUserUseCase(sl()));
  sl.registerLazySingleton(() => GetTransactionsUseCase(sl()));
  sl.registerLazySingleton(() => AddTransactionUseCase(sl(), sl()));

  // Repositories
  sl.registerLazySingleton<IUserRepository>(
    () => UserRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ITransactionRepository>(
    () => TransactionRepositoryImpl(sl()),
  );

  // Data sources
  sl.registerLazySingleton<LocalDataSource>(
    () => LocalDataSourceImpl(sl()),
  );

  // Services
  sl.registerLazySingleton(DatabaseService.new);
}
