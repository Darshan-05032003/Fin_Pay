import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/platform/biometric_authenticator.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/fingerprint/biometric_setup_cubit.dart';
import 'package:fin_pay/screens/auth/widgets/auth_scaffold.dart';
import 'package:fin_pay/screens/auth/widgets/inline_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Optional biometric enrolment: a pulsing fingerprint glyph, the system
/// prompt behind [BiometricAuthenticator], a drawn checkmark on success,
/// a shake with retry on failure, and "not now" always available.
class FingerprintSetupScreen extends StatelessWidget {
  const FingerprintSetupScreen({super.key, this.biometrics});

  /// Injected for tests; defaults to the GetIt registration.
  final BiometricAuthenticator? biometrics;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BiometricSetupCubit(
        biometrics: biometrics ?? GetIt.I<BiometricAuthenticator>(),
        settings: context.read<SettingsCubit>(),
      )..check().ignore(),
      child: const _FingerprintView(),
    );
  }
}

class _FingerprintView extends StatefulWidget {
  const _FingerprintView();

  @override
  State<_FingerprintView> createState() => _FingerprintViewState();
}

class _FingerprintViewState extends State<_FingerprintView> {
  final FpShakeController _shake = FpShakeController();

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _done(BuildContext context) => context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final cubit = context.read<BiometricSetupCubit>();
    return BlocListener<BiometricSetupCubit, BiometricSetupState>(
      listenWhen: (p, n) => p.phase != n.phase || p.attempts != n.attempts,
      listener: (context, state) {
        switch (state.phase) {
          case BiometricPhase.success:
            playHaptic(null, HapticType.success);
          case BiometricPhase.failed:
            _shake.shake();
            playHaptic(null, HapticType.error);
          case BiometricPhase.skipped:
            _done(context);
          case BiometricPhase.checking ||
              BiometricPhase.ready ||
              BiometricPhase.scanning ||
              BiometricPhase.unavailable:
            break;
        }
      },
      child: BlocBuilder<BiometricSetupCubit, BiometricSetupState>(
        builder: (context, state) {
          final success = state.phase == BiometricPhase.success;
          final unavailable = state.phase == BiometricPhase.unavailable;
          return AuthScaffold(
            title: success ? 'Fingerprint added' : 'Unlock with a touch',
            subtitle: success
                ? 'Next time, your fingerprint opens FinPay.'
                : 'Use your fingerprint instead of a password. You can '
                      'change this later in settings.',
            scrollKey: const ValueKey('fingerprint-scroll'),
            footer: success
                ? null
                : FpButton(
                    key: const ValueKey('fingerprint-skip'),
                    label: unavailable ? 'Continue' : 'Not now',
                    variant: FpButtonVariant.ghost,
                    onPressed: cubit.skip,
                  ),
            children: [
              const SizedBox(height: FpSpacing.lg),
              Center(
                child: FpShake(
                  controller: _shake,
                  child: _Glyph(state: state, onTap: cubit.authenticate),
                ),
              ),
              const SizedBox(height: FpSpacing.xl),
              Text(
                switch (state.phase) {
                  BiometricPhase.checking => 'Checking this device…',
                  BiometricPhase.ready => 'Tap the fingerprint to begin.',
                  BiometricPhase.scanning => 'Waiting for your fingerprint…',
                  BiometricPhase.success => 'Recognised.',
                  BiometricPhase.failed => 'Try again, or skip for now.',
                  BiometricPhase.unavailable => 'Skip this step for now.',
                  BiometricPhase.skipped => '',
                },
                key: const ValueKey('fingerprint-status'),
                style: fp.text.bodySmall.copyWith(color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FpSpacing.xl),
              InlineMessage(
                message: state.phase == BiometricPhase.failed || unavailable
                    ? state.message
                    : null,
              ),
              if (success)
                FpButton(
                  key: const ValueKey('fingerprint-continue'),
                  label: 'Continue',
                  size: FpButtonSize.large,
                  onPressed: () => _done(context),
                )
              else if (!unavailable)
                FpButton(
                  key: const ValueKey('fingerprint-scan'),
                  label: state.phase == BiometricPhase.failed
                      ? 'Try again'
                      : 'Use fingerprint',
                  size: FpButtonSize.large,
                  leadingIcon: Icons.fingerprint,
                  isLoading: state.phase == BiometricPhase.scanning,
                  enabled: state.canAuthenticate,
                  onPressed: cubit.authenticate,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The 144 px tile: pulsing fingerprint while ready, spinner while
/// scanning, drawn check on success, alert tint on failure.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.state, required this.onTap});

  final BiometricSetupState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.fp.colors;
    final reduce = FpMotion.of(context).reduce;
    final phase = state.phase;
    final content = switch (phase) {
      BiometricPhase.success => const FpDrawnCheck(
        key: ValueKey('fingerprint-check'),
        size: 88,
        semanticLabel: 'Fingerprint recognised',
      ),
      BiometricPhase.scanning => SizedBox(
        key: const ValueKey('fingerprint-spinner'),
        width: 40,
        height: 40,
        child: CircularProgressIndicator(strokeWidth: 3, color: c.accent),
      ),
      _ => FpPulse(
        key: const ValueKey('fingerprint-pulse'),
        active: phase == BiometricPhase.ready,
        child: Icon(
          Icons.fingerprint,
          size: 80,
          color: phase == BiometricPhase.failed
              ? c.alert
              : phase == BiometricPhase.unavailable
              ? c.textDisabled
              : c.accent,
        ),
      ),
    };
    final tile = FpSurface(
      width: 144,
      height: 144,
      padding: EdgeInsets.zero,
      variant: FpSurfaceVariant.raised,
      child: Center(
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : FpMotion.standard,
          switchInCurve: FpMotion.emphasizedDecelerate,
          switchOutCurve: FpMotion.emphasizedAccelerate,
          child: content,
        ),
      ),
    );
    if (!state.canAuthenticate) return tile;
    return FpPressable(
      key: const ValueKey('fingerprint-glyph'),
      semanticLabel: 'Scan fingerprint',
      onPressed: onTap,
      scale: 0.97,
      child: tile,
    );
  }
}
