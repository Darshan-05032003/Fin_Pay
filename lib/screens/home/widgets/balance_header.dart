import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/blocs/user/user_state.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/screens/home/home_header_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The pinned, collapsing balance header: greeting and bell when expanded;
/// the big balance (odometer count-up on first load) shrinks and docks to
/// the right of the bar as the page scrolls; the eye toggles hide-balance
/// (persisted) everywhere.
class BalanceHeader extends StatelessWidget {
  const BalanceHeader({
    required this.now,
    super.key,
    this.onNotifications,
    this.haptics,
  });

  /// "Now" for the greeting.
  final DateTime now;
  final VoidCallback? onNotifications;
  final HapticService? haptics;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final hidden = context.select<SettingsCubit, bool>(
      (c) => c.state.hideBalance,
    );
    final userState = context.watch<UserBloc>().state;
    return FpCollapsingHeader(
      expandedHeight: HomeHeaderMath.expandedHeight(topPadding),
      collapsedHeight: HomeHeaderMath.collapsedHeight(topPadding),
      rebuildKey: Object.hash(hidden, userState, now.hour),
      builder: (context, t) => _HeaderBody(
        t: t,
        topPadding: topPadding,
        hidden: hidden,
        userState: userState,
        now: now,
        onNotifications: onNotifications,
        haptics: haptics,
      ),
    );
  }
}

class _HeaderBody extends StatelessWidget {
  const _HeaderBody({
    required this.t,
    required this.topPadding,
    required this.hidden,
    required this.userState,
    required this.now,
    this.onNotifications,
    this.haptics,
  });

  final double t;
  final double topPadding;
  final bool hidden;
  final UserState userState;
  final DateTime now;
  final VoidCallback? onNotifications;
  final HapticService? haptics;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final fadeOut = HomeHeaderMath.expandedOnlyOpacity(t);
    final fadeIn = HomeHeaderMath.dockedOnlyOpacity(t);
    final name = userState.user?.fullName ?? '';
    final balanceStyle = fp.text.displayLarge;
    // Line height of the big balance (its text style height × size).
    final balanceHeight = balanceStyle.fontSize! * (balanceStyle.height ?? 1);
    return DecoratedBox(
      key: const ValueKey('home-header-body'),
      decoration: BoxDecoration(
        color: Color.lerp(c.background, c.surface, t),
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: t)),
        ),
      ),
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Greeting + bell (expanded only).
            Positioned(
              left: FpSpacing.lg,
              right: FpSpacing.lg,
              top:
                  topPadding +
                  HomeHeaderMath.greetingTop +
                  HomeHeaderMath.greetingShift(t),
              child: IgnorePointer(
                ignoring: fadeOut == 0,
                child: ExcludeSemantics(
                  excluding: fadeOut == 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${HomeHeaderMath.greetingFor(now)},',
                              style: fp.text.bodySmall.copyWith(
                                color: c.textSecondary.withValues(
                                  alpha: fadeOut,
                                ),
                              ),
                              maxLines: 1,
                            ),
                            Text(
                              name.isEmpty ? 'Welcome' : name,
                              key: const ValueKey('home-name'),
                              style: fp.text.title.copyWith(
                                color: c.textPrimary.withValues(alpha: fadeOut),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      FpPressable(
                        key: const ValueKey('home-notifications'),
                        semanticLabel: 'Notifications',
                        onPressed: onNotifications,
                        haptics: haptics,
                        child: SizedBox(
                          width: FpSpacing.minTapTarget,
                          height: FpSpacing.minTapTarget,
                          child: Icon(
                            Icons.notifications_none_outlined,
                            color: c.textPrimary.withValues(alpha: fadeOut),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Docked title (collapsed only).
            Positioned(
              left: FpSpacing.lg,
              top: topPadding,
              height: HomeHeaderMath.collapsedContent,
              child: ExcludeSemantics(
                excluding: fadeIn == 0,
                child: Center(
                  child: Text(
                    name.isEmpty ? 'FinPay' : HomeHeaderMath.firstName(name),
                    style: fp.text.title.copyWith(
                      color: c.textPrimary.withValues(alpha: fadeIn),
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            // "Available balance" overline (expanded only).
            Positioned(
              left: FpSpacing.lg,
              top: topPadding + HomeHeaderMath.overlineTop,
              child: ExcludeSemantics(
                excluding: fadeOut == 0,
                child: Text(
                  'AVAILABLE BALANCE',
                  style: fp.text.overline.copyWith(
                    color: c.textTertiary.withValues(alpha: fadeOut),
                  ),
                ),
              ),
            ),
            // The balance: shrinks and docks to the right.
            Positioned(
              left: FpSpacing.lg,
              right: FpSpacing.lg + HomeHeaderMath.eyeSlot,
              top:
                  topPadding +
                  HomeHeaderMath.balanceY(t, balanceHeight: balanceHeight),
              height: balanceHeight,
              child: Align(
                alignment: HomeHeaderMath.balanceAlignment(t),
                child: Transform.scale(
                  scale: HomeHeaderMath.balanceScale(t),
                  alignment: HomeHeaderMath.balanceAlignment(t),
                  // A very large balance (or 1.3× text) shrinks to fit
                  // rather than overflowing the header.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: HomeHeaderMath.balanceAlignment(t),
                    child: _Balance(
                      state: userState,
                      hidden: hidden,
                      style: balanceStyle,
                    ),
                  ),
                ),
              ),
            ),
            // Eye toggle: rides from beside the overline into the bar.
            Positioned(
              right: FpSpacing.lg,
              top: topPadding + HomeHeaderMath.eyeY(t),
              child: FpPressable(
                key: const ValueKey('home-hide-balance'),
                semanticLabel: hidden ? 'Show balance' : 'Hide balance',
                haptics: haptics,
                onPressed: () =>
                    context.read<SettingsCubit>().toggleHideBalance(),
                child: SizedBox(
                  width: FpSpacing.minTapTarget,
                  height: FpSpacing.minTapTarget,
                  child: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({
    required this.state,
    required this.hidden,
    required this.style,
  });

  final UserState state;
  final bool hidden;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    switch (state) {
      case UserInitial() || UserLoading():
        return const FpSkeleton(
          key: ValueKey('home-balance-loading'),
          width: 220,
          height: 44,
        );
      case UserError(:final message):
        return FpPressable(
          key: const ValueKey('home-balance-error'),
          semanticLabel: 'Balance unavailable: $message. Tap to retry',
          onPressed: () => context.read<UserBloc>().add(const LoadUserEvent()),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: c.alert),
              const SizedBox(width: FpSpacing.sm),
              Text(
                'Tap to retry',
                style: fp.text.body.copyWith(color: c.alert),
              ),
            ],
          ),
        );
      case UserEmpty():
        return FpAmountText(
          key: const ValueKey('home-balance'),
          paise: 0,
          style: style,
          hide: hidden ? FpAmountHide.mask : FpAmountHide.none,
        );
      case UserContent(:final balance):
        return FpAmountText(
          key: const ValueKey('home-balance'),
          paise: balance.paise,
          style: style,
          animateFirstBuild: true,
          hide: hidden ? FpAmountHide.mask : FpAmountHide.none,
          semanticLabel: hidden
              ? 'Balance hidden'
              : 'Available balance ${balance.format()}',
        );
    }
  }
}
