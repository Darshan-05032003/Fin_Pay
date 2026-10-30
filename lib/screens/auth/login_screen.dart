import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/login/login_cubit.dart';
import 'package:fin_pay/screens/auth/widgets/auth_scaffold.dart';
import 'package:fin_pay/screens/auth/widgets/inline_message.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Email + password sign-in. Validation is inline after the first submit,
/// typed failures (wrong credentials, lockout with a live countdown,
/// storage errors) show under the form with a shake and an error haptic,
/// and the button morphs into a spinner while the hash is checked. The
/// screen is screenshot-protected and re-hides the password when the app
/// goes to the background.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static Clock _clock() =>
      GetIt.I.isRegistered<Clock>() ? GetIt.I<Clock>() : const Clock();

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: BlocProvider(
        create: (context) =>
            LoginCubit(session: context.read<SessionCubit>(), clock: _clock()),
        child: const _LoginView(),
      ),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> with WidgetsBindingObserver {
  final FpShakeController _shake = FpShakeController();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      context.read<LoginCubit>().hidePassword();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordFocus.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final cubit = context.read<LoginCubit>();
    return BlocListener<LoginCubit, LoginState>(
      listenWhen: (p, n) => p.failures != n.failures || p.status != n.status,
      listener: (context, state) {
        if (state.status == LoginStatus.failure) {
          _shake.shake();
          playHaptic(null, HapticType.error);
        } else if (state.status == LoginStatus.success) {
          playHaptic(null, HapticType.success);
        }
      },
      child: BlocBuilder<LoginCubit, LoginState>(
        builder: (context, state) => AuthScaffold(
          title: 'Welcome back',
          subtitle: 'Sign in to pick up where you left off.',
          onBack: () => context.go(AppRoutes.welcome),
          scrollKey: const ValueKey('login-scroll'),
          footer: FpButton(
            label: 'Create an account',
            variant: FpButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.createAccount),
          ),
          children: [
            FpShake(
              controller: _shake,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FpTextField(
                      key: const ValueKey('login-email'),
                      label: 'Email',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      errorText: state.emailError,
                      enabled: !state.isLocked,
                      prefix: const Icon(Icons.alternate_email),
                      onChanged: cubit.emailChanged,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: FpSpacing.lg),
                    FpTextField(
                      key: const ValueKey('login-password'),
                      label: 'Password',
                      hint: 'Your password',
                      focusNode: _passwordFocus,
                      obscureText: !state.showPassword,
                      obscureToggle: false,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      errorText: state.passwordError,
                      enabled: !state.isLocked,
                      prefix: const Icon(Icons.lock_outline),
                      suffix: IconButton(
                        key: const ValueKey('login-password-toggle'),
                        tooltip: state.showPassword
                            ? 'Hide password'
                            : 'Show password',
                        constraints: const BoxConstraints(
                          minWidth: FpSpacing.minTapTarget,
                          minHeight: FpSpacing.minTapTarget,
                        ),
                        onPressed: cubit.togglePasswordVisibility,
                        icon: Icon(
                          state.showPassword
                              ? Icons.visibility_off
                              : Icons.visibility_outlined,
                        ),
                      ),
                      onChanged: cubit.passwordChanged,
                      onSubmitted: (_) => cubit.submit(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FpSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FpButton(
                label: 'Forgot password?',
                variant: FpButtonVariant.ghost,
                size: FpButtonSize.small,
                expand: false,
                onPressed: () => context.push(AppRoutes.passwordReset),
              ),
            ),
            const SizedBox(height: FpSpacing.lg),
            InlineMessage(
              key: const ValueKey('login-message'),
              message: state.status == LoginStatus.failure
                  ? state.message
                  : null,
            ),
            FpButton(
              key: const ValueKey('login-submit'),
              label: state.isLocked ? 'Locked' : 'Sign in',
              size: FpButtonSize.large,
              isLoading: state.status == LoginStatus.submitting,
              enabled: state.canSubmit,
              onPressed: cubit.submit,
            ),
            const SizedBox(height: FpSpacing.lg),
            Text(
              'Demo build: the sign-in details are in the README.',
              style: fp.text.caption.copyWith(color: c.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
