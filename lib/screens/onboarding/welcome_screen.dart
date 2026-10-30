import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/session/session_state.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/widgets/spring_rise.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The root splash: the brand mark reveals once, then the calls to action
/// rise in. A returning user (onboarding already seen) is offered "sign in"
/// first; a new one is sent through the onboarding pages.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final seen = context.select<SettingsCubit, bool>(
      (cubit) => cubit.state.onboardingSeen,
    );
    final ready = context.select<SessionCubit, bool>(
      (cubit) => cubit.state is! SessionUnknown,
    );
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FpSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              FpStaggeredEntrance(
                children: [
                  const _BrandMark(),
                  const SizedBox(height: FpSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      'FinPay',
                      style: fp.text.displayLarge,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: FpSpacing.sm),
                  Text('Your money. Your move.', style: fp.text.displayItalic),
                  const SizedBox(height: FpSpacing.lg),
                  Text(
                    'Pay, track and protect, from one place.',
                    style: fp.text.bodySmall,
                  ),
                ],
              ),
              const Spacer(),
              if (ready)
                SpringRise(
                  key: const ValueKey('welcome-cta'),
                  delay: FpMotion.emphasized,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FpButton(
                        label: seen ? 'Sign in' : 'Get started',
                        size: FpButtonSize.large,
                        onPressed: () => context.go(
                          seen ? AppRoutes.login : AppRoutes.onboarding,
                        ),
                      ),
                      const SizedBox(height: FpSpacing.md),
                      FpButton(
                        label: seen
                            ? 'Create an account'
                            : 'I already have an account',
                        variant: FpButtonVariant.ghost,
                        onPressed: () => context.go(
                          seen ? AppRoutes.createAccount : AppRoutes.login,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The code-drawn mark: an accent NeoPOP tile with a rupee glyph.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return Semantics(
      label: 'FinPay logo',
      image: true,
      child: ExcludeSemantics(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FpSurface(
            color: c.accent,
            edge: FpEdge.accent,
            width: 72,
            height: 72,
            padding: EdgeInsets.zero,
            child: Center(
              child: Text(
                '₹',
                style: fp.text.headline.copyWith(fontSize: 32, color: c.onPop),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
