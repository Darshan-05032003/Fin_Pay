import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_event.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_event.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/routes/app_router.dart';
import 'package:fin_pay/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    await di.init();
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
        BlocProvider(create: (_) => di.sl<UserBloc>()..add(const LoadUserEvent())),
        BlocProvider(
          create: (_) => di.sl<TransactionBloc>()..add(const LoadTransactionsEvent()),
        ),
        BlocProvider(create: (_) => di.sl<CardBloc>()..add(const LoadCardsEvent())),
        BlocProvider(
          create: (_) =>
              di.sl<NotificationBloc>()..add(const LoadNotificationsEvent()),
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
            ).copyWith(textScaler: const TextScaler.linear(1)),
            child: child!,
          );
        },
      ),
    );
  }
}
