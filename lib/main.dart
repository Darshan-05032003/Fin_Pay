import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'constants/theme.dart';
import 'routes/app_router.dart';
import 'services/user_service.dart';
import 'core/di/dependency_injection.dart';
import 'blocs/user/user_bloc.dart';
import 'blocs/user/user_event.dart';
import 'blocs/transaction/transaction_bloc.dart';
import 'blocs/transaction/transaction_event.dart';
import 'blocs/card/card_bloc.dart';
import 'blocs/card/card_event.dart';
import 'blocs/notification/notification_bloc.dart';
import 'blocs/notification/notification_event.dart';
import 'core/logger.dart';

/// Main entry point of the application
///
/// Initializes all dependencies, services, and runs the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize dependency injection
  try {
    await DependencyInjection.init();
    Logger.info('Dependency injection initialized');
  } catch (e) {
    Logger.error('Failed to initialize dependency injection', e);
  }

  // Initialize default user
  try {
    await UserService.init();
    Logger.info('Default user initialized');
  } catch (e) {
    Logger.error('Failed to initialize default user', e);
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => UserBloc()..add(const LoadUserEvent())),
        BlocProvider(
          create: (_) => TransactionBloc()..add(const LoadTransactionsEvent()),
        ),
        BlocProvider(create: (_) => CardBloc()..add(const LoadCardsEvent())),
        BlocProvider(
          create: (_) =>
              NotificationBloc()..add(const LoadNotificationsEvent()),
        ),
      ],
      child: MaterialApp(
        title: 'FinPay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.lightTheme,
        themeMode: ThemeMode.dark,
        initialRoute: '/',
        onGenerateRoute: AppRouter.generateRoute,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child!,
          );
        },
      ),
    );
  }
}
