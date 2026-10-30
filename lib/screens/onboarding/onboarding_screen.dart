import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/widgets/spring_rise.dart';
import 'package:fin_pay/screens/onboarding/onboarding_cubit.dart';
import 'package:fin_pay/screens/onboarding/onboarding_illustrations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Three swipeable pages with layered, code-drawn illustrations that move
/// at different speeds, a morphing page indicator and a CTA that rises in
/// on a spring. Finishing (or skipping) records "onboarding seen".
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          OnboardingCubit(settings: context.read<SettingsCubit>()),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncPage(int page) {
    if (!_controller.hasClients) return;
    if ((_controller.page ?? _controller.initialPage).round() == page) return;
    if (FpMotion.of(context).reduce) {
      _controller.jumpToPage(page);
      return;
    }
    _controller.animateToPage(
      page,
      duration: FpMotion.screen,
      curve: FpMotion.emphasizedDecelerate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final cubit = context.read<OnboardingCubit>();
    final pages = OnboardingCubit.pages;
    return BlocListener<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        if (state.completed) {
          context.go(AppRoutes.login);
          return;
        }
        _syncPage(state.page);
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.lg,
                  FpSpacing.sm,
                  FpSpacing.lg,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FpButton(
                      label: 'Skip',
                      variant: FpButtonVariant.ghost,
                      size: FpButtonSize.small,
                      expand: false,
                      semanticLabel: 'Skip onboarding',
                      onPressed: cubit.skip,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  key: const ValueKey('onboarding-pages'),
                  controller: _controller,
                  onPageChanged: cubit.pageChanged,
                  itemCount: pages.length,
                  itemBuilder: (context, index) => _OnboardingPage(
                    spec: pages[index],
                    index: index,
                    controller: _controller,
                  ),
                ),
              ),
              BlocBuilder<OnboardingCubit, OnboardingState>(
                buildWhen: (p, n) => p.page != n.page,
                builder: (context, state) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FpSpacing.lg,
                    vertical: FpSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: FpPageIndicator(
                          count: pages.length,
                          index: state.page,
                        ),
                      ),
                      const SizedBox(height: FpSpacing.xl),
                      SpringRise(
                        key: const ValueKey('onboarding-cta'),
                        delay: FpMotion.standard,
                        child: FpButton(
                          label: state.isLast(pages.length)
                              ? 'Get started'
                              : 'Next',
                          size: FpButtonSize.large,
                          onPressed: cubit.next,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.spec,
    required this.index,
    required this.controller,
  });

  final OnboardingPageSpec spec;
  final int index;
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: FpSpacing.xl,
        vertical: FpSpacing.lg,
      ),
      children: [
        Center(
          child: OnboardingIllustration(
            spec: spec,
            index: index,
            controller: controller,
          ),
        ),
        const SizedBox(height: FpSpacing.xxl),
        Semantics(
          header: true,
          child: Text(
            spec.title,
            style: fp.text.headline,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: FpSpacing.md),
        Text(spec.body, style: fp.text.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}
