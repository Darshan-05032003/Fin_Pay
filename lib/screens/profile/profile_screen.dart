import 'dart:async';

import 'package:fin_pay/blocs/session/session_cubit.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/blocs/user/user_state.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/profile/profile_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Profile tab: a parallax avatar header fed by [UserBloc], NeoPOP
/// toggles bound to [SettingsCubit] (persisted), the design gallery (debug
/// only), About, and a confirmed logout through [ProfileCubit].
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.showGallery});

  /// Branch index of this tab in the shell.
  static const int tabIndex = 3;

  /// The attribution shown in the About sheet (README wording).
  static const String aboutText =
      "FinPay — inspired by CRED's NeoPOP design language; "
      'not affiliated with CRED';

  /// Whether the "Design gallery" row is offered; defaults to debug builds.
  final bool? showGallery;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileCubit(session: context.read<SessionCubit>()),
      child: _ProfileView(showGallery: showGallery ?? kDebugMode),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView({required this.showGallery});

  final bool showGallery;

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final user = context.read<UserBloc>();
    if (user.state is UserInitial) user.add(const LoadUserEvent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final cubit = context.read<ProfileCubit>()..startLogout();
    final confirmed = await FpBottomSheet.show<bool>(
      context,
      title: 'Log out of FinPay?',
      builder: (sheet) => Column(
        key: const ValueKey('logout-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your account and activity stay on this device. You will sign '
            'in again next time.',
            style: sheet.fp.text.bodySmall,
          ),
          const SizedBox(height: FpSpacing.xl),
          FpButton(
            key: const ValueKey('logout-confirm'),
            label: 'Log out',
            variant: FpButtonVariant.danger,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
          const SizedBox(height: FpSpacing.md),
          FpButton(
            key: const ValueKey('logout-cancel'),
            label: 'Stay signed in',
            variant: FpButtonVariant.ghost,
            onPressed: () => Navigator.of(sheet).pop(false),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await cubit.confirmLogout();
    } else {
      cubit.cancelLogout();
    }
  }

  Future<void> _showAbout(BuildContext context) {
    return FpBottomSheet.show<void>(
      context,
      title: 'About FinPay',
      builder: (sheet) => Column(
        key: const ValueKey('about-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ProfileScreen.aboutText, style: sheet.fp.text.body),
          const SizedBox(height: FpSpacing.md),
          Text(
            'Everything in this app is simulated and stays on your device: '
            'payments, contacts, OTPs and biometrics never leave it.',
            style: sheet.fp.text.bodySmall,
          ),
          const SizedBox(height: FpSpacing.xl),
          FpButton(
            label: 'Done',
            variant: FpButtonVariant.secondary,
            onPressed: () => Navigator.of(sheet).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return BlocListener<ProfileCubit, LogoutStatus>(
      listener: (context, status) {
        switch (status) {
          case LogoutStatus.signedOut:
            playHaptic(null, HapticType.success);
          case LogoutStatus.failed:
            playHaptic(null, HapticType.error);
            FpToast.show(
              context,
              message: 'Could not log out. Try again.',
              kind: FpToastKind.error,
            );
          case LogoutStatus.idle ||
              LogoutStatus.confirming ||
              LogoutStatus.signingOut:
            break;
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        // The header sits behind the list and follows the scroll at 0.4×,
        // so the content slides over it (parallax).
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FpParallax(
                controller: _scroll,
                factor: 0.4,
                child: const _ProfileHeader(),
              ),
            ),
            ListView(
              key: const ValueKey('profile-scroll'),
              controller: _scroll,
              padding: const EdgeInsets.only(
                top: _ProfileHeader.height,
                bottom: FpSpacing.xxl,
              ),
              children: [
                ColoredBox(
                  color: c.background,
                  child: Padding(
                    padding: FpSpacing.page,
                    child: FpStaggeredEntrance(
                      children: [
                        const _SectionTitle('Preferences'),
                        const _SettingsSection(),
                        const SizedBox(height: FpSpacing.lg),
                        const _SectionTitle('More'),
                        FpSurface(
                          variant: FpSurfaceVariant.flat,
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              if (widget.showGallery)
                                _LinkRow(
                                  key: const ValueKey('profile-gallery'),
                                  icon: Icons.palette_outlined,
                                  label: 'Design gallery',
                                  caption: 'Every component in every state',
                                  onTap: () => unawaited(
                                    context.push(AppRoutes.gallery),
                                  ),
                                ),
                              _LinkRow(
                                key: const ValueKey('profile-about'),
                                icon: Icons.info_outline,
                                label: 'About',
                                caption: 'Version, attribution and demo data',
                                onTap: () => unawaited(_showAbout(context)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: FpSpacing.xl),
                        BlocBuilder<ProfileCubit, LogoutStatus>(
                          builder: (context, status) => FpButton(
                            key: const ValueKey('profile-logout'),
                            label: 'Log out',
                            variant: FpButtonVariant.danger,
                            leadingIcon: Icons.logout,
                            isLoading: status == LogoutStatus.signingOut,
                            onPressed: () => _confirmLogout(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar with initials, name and email from [UserBloc]; slides at 0.4×
/// the scroll through [FpParallax].
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  /// Fixed height so the list can leave room for it; the content fits at
  /// 1.3× text scale with slack.
  static const double height = 264;

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        final user = state.user;
        final loading = state is UserLoading || state is UserInitial;
        final name = user?.fullName ?? (loading ? '' : 'FinPay user');
        final email = user?.email ?? '';
        return Semantics(
          key: const ValueKey('profile-header'),
          label: loading
              ? 'Loading profile'
              : 'Profile: $name${email.isEmpty ? '' : ', $email'}',
          child: ExcludeSemantics(
            child: Container(
              height: height,
              alignment: Alignment.center,
              padding: const EdgeInsets.fromLTRB(
                FpSpacing.lg,
                FpSpacing.xl,
                FpSpacing.lg,
                FpSpacing.lg,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.surfaceRaised, c.background],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FpSurface(
                    variant: FpSurfaceVariant.raised,
                    width: 88,
                    height: 88,
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: loading
                          ? const FpSkeleton(width: 40, height: 24)
                          : Text(
                              initials(name),
                              key: const ValueKey('profile-initials'),
                              style: fp.text.displaySmall,
                            ),
                    ),
                  ),
                  const SizedBox(height: FpSpacing.lg),
                  if (loading)
                    const FpSkeletonGroup(
                      child: Column(
                        children: [
                          FpSkeleton(width: 160, height: 20),
                          SizedBox(height: FpSpacing.sm),
                          FpSkeleton(width: 200, height: 14),
                        ],
                      ),
                    )
                  else ...[
                    Text(
                      name,
                      key: const ValueKey('profile-name'),
                      style: fp.text.headline,
                      textAlign: TextAlign.center,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: FpSpacing.xs),
                      Text(
                        email,
                        key: const ValueKey('profile-email'),
                        style: fp.text.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FpSpacing.sm, top: FpSpacing.sm),
      child: Text(title.toUpperCase(), style: context.fp.text.overline),
    );
  }
}

/// The four persisted preferences as NeoPOP toggles.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SettingsCubit>();
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => FpSurface(
        variant: FpSurfaceVariant.flat,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _ToggleRow(
              key: const ValueKey('setting-haptics'),
              icon: Icons.vibration,
              label: 'Haptics',
              caption: 'Feel taps, ticks and confirmations',
              value: state.hapticsEnabled,
              onChanged: (v) => unawaited(cubit.setHapticsEnabled(enabled: v)),
            ),
            _ToggleRow(
              key: const ValueKey('setting-reduce-motion'),
              icon: Icons.motion_photos_off_outlined,
              label: 'Reduce motion',
              caption: 'Fewer animations, instant transitions',
              value: state.reduceMotion,
              onChanged: (v) => unawaited(cubit.setReduceMotion(enabled: v)),
            ),
            _ToggleRow(
              key: const ValueKey('setting-hide-balance'),
              icon: Icons.visibility_off_outlined,
              label: 'Hide balance',
              caption: 'Mask amounts until you tap the eye',
              value: state.hideBalance,
              onChanged: (v) => unawaited(cubit.setHideBalance(hidden: v)),
            ),
            _ToggleRow(
              key: const ValueKey('setting-biometric'),
              icon: Icons.fingerprint,
              label: 'Biometric sign-in',
              caption: 'Use your fingerprint to unlock',
              value: state.biometricEnabled,
              onChanged: (v) =>
                  unawaited(cubit.setBiometricEnabled(enabled: v)),
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
    super.key,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String caption;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        FpSpacing.lg,
        FpSpacing.md,
        FpSpacing.md,
        FpSpacing.md,
      ),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: c.textSecondary)),
          const SizedBox(width: FpSpacing.md),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: fp.text.body),
                  const SizedBox(height: 2),
                  Text(caption, style: fp.text.caption),
                ],
              ),
            ),
          ),
          const SizedBox(width: FpSpacing.md),
          FpToggle(value: value, semanticLabel: label, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return FpPressable(
      semanticLabel: label,
      scale: 0.98,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FpSpacing.lg,
          vertical: FpSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.textSecondary),
            const SizedBox(width: FpSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: fp.text.body),
                  const SizedBox(height: 2),
                  Text(caption, style: fp.text.caption),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
