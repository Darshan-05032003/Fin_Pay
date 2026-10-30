import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/create_account/create_account_cubit.dart';
import 'package:fin_pay/screens/auth/widgets/auth_scaffold.dart';
import 'package:fin_pay/screens/auth/widgets/inline_message.dart';
import 'package:fin_pay/screens/auth/widgets/password_strength_meter.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:fin_pay/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Sign-up form. The [CreateAccountCubit] is provided by the auth shell
/// route and shared with the verification step, so the password never
/// travels through route arguments.
class CreateAccountScreen extends StatelessWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const SecureScreen(child: _CreateAccountView());
}

class _CreateAccountView extends StatefulWidget {
  const _CreateAccountView();

  @override
  State<_CreateAccountView> createState() => _CreateAccountViewState();
}

class _CreateAccountViewState extends State<_CreateAccountView>
    with WidgetsBindingObserver {
  final FpShakeController _shake = FpShakeController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      context.read<CreateAccountCubit>().hidePassword();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shake.dispose();
    super.dispose();
  }

  void _continue(BuildContext context) {
    final cubit = context.read<CreateAccountCubit>()..submit();
    if (cubit.state.status == CreateAccountStatus.pendingVerification) {
      playHaptic(null, HapticType.medium);
      unawaited(context.push(AppRoutes.verification));
    } else {
      _shake.shake();
      playHaptic(null, HapticType.error);
    }
  }

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
    final cubit = context.read<CreateAccountCubit>();
    return BlocBuilder<CreateAccountCubit, CreateAccountState>(
      builder: (context, state) => AuthScaffold(
        title: 'Create your account',
        subtitle: 'A minute now, a lifetime of tap-to-pay.',
        onBack: () => _back(context),
        scrollKey: const ValueKey('create-account-scroll'),
        children: [
          FpShake(
            controller: _shake,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FpTextField(
                    key: const ValueKey('create-name'),
                    label: 'Full name',
                    hint: 'As on your bank account',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    maxLength: Validators.maxNameLength + 10,
                    errorText: state.nameError,
                    enabled: !state.isBusy,
                    onChanged: cubit.nameChanged,
                  ),
                  const SizedBox(height: FpSpacing.lg),
                  FpTextField(
                    key: const ValueKey('create-email'),
                    label: 'Email',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    maxLength: Validators.maxEmailLength,
                    errorText: state.emailError,
                    enabled: !state.isBusy,
                    onChanged: cubit.emailChanged,
                  ),
                  const SizedBox(height: FpSpacing.lg),
                  FpTextField(
                    key: const ValueKey('create-phone'),
                    label: 'Mobile number',
                    hint: '10-digit number',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9 +()-]')),
                      LengthLimitingTextInputFormatter(18),
                    ],
                    prefix: const Icon(Icons.phone_outlined),
                    helperText: 'Your verification code is sent here.',
                    errorText: state.phoneError,
                    enabled: !state.isBusy,
                    onChanged: cubit.phoneChanged,
                  ),
                  const SizedBox(height: FpSpacing.lg),
                  FpTextField(
                    key: const ValueKey('create-password'),
                    label: 'Password',
                    hint: 'At least 8 characters',
                    obscureText: !state.showPassword,
                    obscureToggle: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    maxLength: Validators.maxPasswordLength + 10,
                    errorText: state.passwordError,
                    enabled: !state.isBusy,
                    suffix: IconButton(
                      key: const ValueKey('create-password-toggle'),
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
                    onSubmitted: (_) => _continue(context),
                  ),
                  const SizedBox(height: FpSpacing.sm),
                  PasswordStrengthMeter(strength: state.strength),
                ],
              ),
            ),
          ),
          const SizedBox(height: FpSpacing.xl),
          Text(
            'By continuing you agree to the FinPay terms of service and '
            'privacy policy.',
            style: fp.text.caption.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: FpSpacing.lg),
          InlineMessage(
            message: state.status == CreateAccountStatus.failed
                ? state.errorMessage
                : null,
          ),
          FpButton(
            key: const ValueKey('create-submit'),
            label: 'Continue',
            size: FpButtonSize.large,
            isLoading: state.isBusy,
            onPressed: () => _continue(context),
          ),
          const SizedBox(height: FpSpacing.md),
          FpButton(
            label: 'I already have an account',
            variant: FpButtonVariant.ghost,
            onPressed: () => _back(context),
          ),
        ],
      ),
    );
  }
}
