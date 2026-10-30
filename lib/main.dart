import 'package:fin_pay/app.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Entry point: wires dependencies, restores settings and session, runs.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
}
