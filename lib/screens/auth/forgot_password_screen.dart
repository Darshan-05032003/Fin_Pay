import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/forgot_password/forgot_password_cubit.dart';
import 'package:fin_pay/screens/auth/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Email step of the password reset, with a simulated send and a success
/// state that never reveals whether the address has an account.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key, this.sendDelay});

  /// Simulated network time (tests pass zero).
  final Duration? sendDelay;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sendDelay == null
          ? ForgotPasswordCubit()
          : ForgotPasswordCubit(delay: sendDelay!),
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatelessWidget {
  const _ForgotPasswordView();

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final cubit = context.read<ForgotPasswordCubit>();
    return BlocListener<ForgotPasswordCubit, ForgotPasswordState>(
      listenWhen: (p, n) => p.status != n.status,
      listener: (context, state) {
        if (state.status == ForgotPasswordStatus.sent) {
          playHaptic(null, HapticType.success);
        }
      },
      child: BlocBuilder<ForgotPasswordCubit, ForgotPasswordState>(
        builder: (context, state) {
          final sent = state.status == ForgotPasswordStatus.sent;
          return AuthScaffold(
            title: sent ? 'Check your inbox' : 'Forgot your password?',
            subtitle: sent
                ? null
                : 'Enter the email on your account and we will send a '
                      'link to reset it.',
            onBack: () => _back(context),
            scrollKey: const ValueKey('forgot-scroll'),
            children: [
              AnimatedSwitcher(
                duration: FpMotion.of(context).scaled(FpMotion.emphasized),
                switchInCurve: FpMotion.emphasizedDecelerate,
                switchOutCurve: FpMotion.emphasizedAccelerate,
                child: sent
                    ? Column(
                        key: const ValueKey('forgot-sent'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: FpSurface(
                              width: 112,
                              height: 112,
                              padding: EdgeInsets.zero,
                              child: Center(
                                child: FpDrawnCheck(
                                  size: 72,
                                  semanticLabel: 'Reset link sent',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: FpSpacing.xl),
                          Text(
                            'If an account exists for ${state.email}, a '
                            'reset link is on its way. It expires in '
                            '15 minutes.',
                            style: fp.text.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: FpSpacing.xl),
                          FpButton(
                            key: const ValueKey('forgot-done'),
                            label: 'Back to sign in',
                            size: FpButtonSize.large,
                            onPressed: () => _back(context),
                          ),
                          const SizedBox(height: FpSpacing.md),
                          FpButton(
                            key: const ValueKey('forgot-again'),
                            label: 'Use a different email',
                            variant: FpButtonVariant.ghost,
                            onPressed: cubit.reset,
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('forgot-form'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FpTextField(
                            key: const ValueKey('forgot-email'),
                            label: 'Email',
                            hint: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.email],
                            prefix: const Icon(Icons.alternate_email),
                            errorText: state.emailError,
                            enabled:
                                state.status != ForgotPasswordStatus.submitting,
                            onChanged: cubit.emailChanged,
                            onSubmitted: (_) => cubit.submit(),
                          ),
                          const SizedBox(height: FpSpacing.xl),
                          FpButton(
                            key: const ValueKey('forgot-submit'),
                            label: 'Send reset link',
                            size: FpButtonSize.large,
                            isLoading:
                                state.status == ForgotPasswordStatus.submitting,
                            onPressed: cubit.submit,
                          ),
                          const SizedBox(height: FpSpacing.lg),
                          Text(
                            'Demo build: no email is sent.',
                            style: fp.text.caption.copyWith(
                              color: c.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
