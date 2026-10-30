import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_event.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_event.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Largest text scale the layouts are tested at. The system setting is
/// honoured up to this factor (WCAG 1.4.4 asks for 200% of *content* text,
/// which the balance and amount components handle on their own).
const double kMaxTextScale = 1.3;

/// The root widget: blocs, theme, router and the accessibility overrides.
class FinPayApp extends StatefulWidget {
  const FinPayApp({super.key, this.router});

  /// Overrides the router (tests).
  final GoRouter? router;

  @override
  State<FinPayApp> createState() => _FinPayAppState();
}

class _FinPayAppState extends State<FinPayApp> {
  late final GoRouter _router =
      widget.router ?? AppRouter.build(session: di.sl<SessionCubit>());

  @override
  void dispose() {
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SessionCubit>.value(value: di.sl<SessionCubit>()),
        BlocProvider<SettingsCubit>.value(value: di.sl<SettingsCubit>()),
        BlocProvider(
          create: (_) => di.sl<UserBloc>()..add(const LoadUserEvent()),
        ),
        BlocProvider(
          create: (_) =>
              di.sl<TransactionBloc>()..add(const LoadTransactionsEvent()),
        ),
        BlocProvider(
          create: (_) => di.sl<CardBloc>()..add(const LoadCardsEvent()),
        ),
        BlocProvider(
          create: (_) =>
              di.sl<NotificationBloc>()..add(const LoadNotificationsEvent()),
        ),
      ],
      child: MaterialApp.router(
        title: 'FinPay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: _router,
        builder: (context, child) => AccessibilityScope(child: child!),
      ),
    );
  }
}

/// Applies the app-wide accessibility rules to the [MediaQuery]:
///
/// * the system text scale is honoured but clamped to [kMaxTextScale];
/// * `disableAnimations` is forced on when the reduce-motion setting is on,
///   so every animation that checks `MediaQuery.disableAnimationsOf` (and
///   the page transitions) degrades to a cut.
class AccessibilityScope extends StatelessWidget {
  const AccessibilityScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reduceMotion = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.reduceMotion,
    );
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: kMaxTextScale),
        disableAnimations: media.disableAnimations || reduceMotion,
      ),
      child: child,
    );
  }
}
