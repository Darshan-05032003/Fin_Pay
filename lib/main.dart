import 'package:fin_pay/app.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

/// Entry point: wires dependencies, restores settings and session, runs.
///
/// The native splash stays up while dependencies, settings and the session
/// load, and is removed once the first Flutter frame is scheduled, so the
/// hand-off is splash → welcome/home with no blank frame in between (the
/// splash colour equals `FpColors.background`, the theme's scaffold colour).
Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await di.init();

  final seeded = await di.sl<AuthRepository>().ensureDemoAccount();
  if (seeded case Failure(:final message, :final error)) {
    Logger.error('Demo account could not be seeded: $message', error);
  }

  await di.sl<SettingsCubit>().load();
  await di.sl<SessionCubit>().restore();

  runApp(const FinPayApp());
  FlutterNativeSplash.remove();
}
