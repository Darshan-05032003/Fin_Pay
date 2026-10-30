import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/create_account/create_account_cubit.dart';
import 'package:fin_pay/screens/auth/verification/otp_cubit.dart';
import 'package:fin_pay/screens/auth/verification/otp_machine.dart';
import 'package:fin_pay/screens/auth/widgets/auth_scaffold.dart';
import 'package:fin_pay/screens/auth/widgets/inline_message.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Six-digit code entry for the sign-up flow. Reads the pending sign-up
/// from the shared [CreateAccountCubit]; opened without one (deep link,
/// process death) it shows a "start again" guard instead of inventing a
/// session.
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  static Clock _clock() =>
      GetIt.I.isRegistered<Clock>() ? GetIt.I<Clock>() : const Clock();

  @override
  Widget build(BuildContext context) {
    final signUp = context.watch<CreateAccountCubit>();
    final code = signUp.expectedOtp;
    if (code.isEmpty) return const _ExpiredView();
    return SecureScreen(
      child: BlocProvider(
        key: ValueKey('otp-${signUp.state.phone}'),
        create: (_) => OtpCubit(expectedCode: code, clock: _clock()),
        child: const _VerificationView(),
      ),
    );
  }
}

class _ExpiredView extends StatelessWidget {
  const _ExpiredView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fp.colors.background,
      body: SafeArea(
        child: Center(
          child: FpErrorState(
            icon: Icons.timer_off_outlined,
            title: 'Start again',
            message:
                'Your sign-up session has ended. Enter your details once '
                'more to get a new code.',
            retryLabel: 'Create account',
            onRetry: () => context.go(AppRoutes.createAccount),
          ),
        ),
      ),
    );
  }
}

class _VerificationView extends StatelessWidget {
  const _VerificationView();

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final otp = context.read<OtpCubit>();
    final signUp = context.read<CreateAccountCubit>();
    return MultiBlocListener(
      listeners: [
        BlocListener<OtpCubit, OtpState>(
          listenWhen: (p, n) => p.phase != n.phase,
          listener: (context, state) {
            if (state.phase == OtpPhase.verified) {
              playHaptic(null, HapticType.success);
              unawaited(signUp.completeSignUp());
            } else if (state.phase == OtpPhase.locked) {
              playHaptic(null, HapticType.error);
            }
          },
        ),
        BlocListener<CreateAccountCubit, CreateAccountState>(
          listenWhen: (p, n) => p.status != n.status,
          listener: (context, state) {
            if (state.status == CreateAccountStatus.completed) {
              context.go(AppRoutes.fingerprintSetup);
            } else if (state.status == CreateAccountStatus.failed) {
              playHaptic(null, HapticType.error);
            }
          },
        ),
      ],
      child: BlocBuilder<CreateAccountCubit, CreateAccountState>(
        builder: (context, signUpState) => BlocBuilder<OtpCubit, OtpState>(
          builder: (context, state) {
            final verified = state.phase == OtpPhase.verified;
            final locked = state.phase == OtpPhase.locked;
            final seconds = state.resendRemaining.inSeconds;
            return AuthScaffold(
              title: 'Enter the code',
              subtitle: 'We sent a 6-digit code to ${signUpState.maskedPhone}.',
              onBack: () => context.pop(),
              scrollKey: const ValueKey('verification-scroll'),
              children: [
                AnimatedSwitcher(
                  duration: FpMotion.of(context).scaled(FpMotion.emphasized),
                  switchInCurve: FpMotion.emphasizedDecelerate,
                  switchOutCurve: FpMotion.emphasizedAccelerate,
                  child: verified
                      ? const _VerifiedBlock()
                      : Column(
                          key: const ValueKey('otp-entry'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FpOtpField(
                              key: const ValueKey('otp-field'),
                              value: state.digits,
                              error: state.phase == OtpPhase.wrong,
                              enabled: state.acceptsInput,
                              autofocus: true,
                              onChanged: otp.input,
                              onCompleted: (_) => otp.submit(),
                            ),
                            const SizedBox(height: FpSpacing.md),
                            if (state.attempts > 0 && !locked)
                              Text(
                                state.remainingAttempts == 1
                                    ? 'Wrong code. 1 attempt left.'
                                    : 'Wrong code. '
                                          '${state.remainingAttempts} '
                                          'attempts left.',
                                key: const ValueKey('otp-attempts'),
                                style: fp.text.caption.copyWith(color: c.alert),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: FpSpacing.xl),
                InlineMessage(
                  message: locked
                      ? 'Too many wrong codes. Go back and start again.'
                      : signUpState.status == CreateAccountStatus.failed
                      ? signUpState.errorMessage
                      : null,
                ),
                if (!verified) ...[
                  Row(
                    children: [
                      FpCountdownRing(
                        key: const ValueKey('otp-countdown'),
                        progress: state.resendProgress,
                        label: '$seconds',
                        size: 48,
                        semanticLabel: state.canResend
                            ? 'You can resend the code now'
                            : 'Resend available in $seconds seconds',
                      ),
                      const SizedBox(width: FpSpacing.md),
                      Expanded(
                        child: FpButton(
                          key: const ValueKey('otp-resend'),
                          label: 'Resend code',
                          variant: FpButtonVariant.ghost,
                          size: FpButtonSize.small,
                          enabled: state.canResend,
                          onPressed: () {
                            otp.resend();
                            FpToast.show(
                              context,
                              message: 'A new code is on its way.',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FpSpacing.xl),
                  FpButton(
                    key: const ValueKey('otp-verify'),
                    label: 'Verify',
                    size: FpButtonSize.large,
                    isLoading: state.phase == OtpPhase.verifying,
                    enabled: state.complete && state.acceptsInput,
                    onPressed: otp.submit,
                  ),
                ] else if (signUpState.status ==
                    CreateAccountStatus.failed) ...[
                  FpButton(
                    key: const ValueKey('otp-retry'),
                    label: 'Try again',
                    size: FpButtonSize.large,
                    onPressed: signUp.completeSignUp,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VerifiedBlock extends StatelessWidget {
  const _VerifiedBlock();

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final busy = context.select<CreateAccountCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );
    return Column(
      key: const ValueKey('otp-verified'),
      children: [
        const FpSurface(
          width: 112,
          height: 112,
          padding: EdgeInsets.zero,
          child: Center(
            child: FpDrawnCheck(size: 72, semanticLabel: 'Code verified'),
          ),
        ),
        const SizedBox(height: FpSpacing.lg),
        Text('Verified', style: fp.text.title),
        const SizedBox(height: FpSpacing.xs),
        Text(
          busy ? 'Setting up your account…' : 'All set.',
          style: fp.text.bodySmall.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
