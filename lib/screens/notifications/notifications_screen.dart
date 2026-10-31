import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_event.dart';
import 'package:fin_pay/blocs/notification/notification_state.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// `/notifications`: the app-wide [NotificationBloc]'s list with a staggered
/// entrance, swipe to dismiss with Undo, a pulsing unread dot, mark-read on
/// tap and "Mark all read".
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  /// How many rows take part in the staggered entrance (the rest appear
  /// in place, so a long list never waits).
  static const int staggeredRows = 12;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  StreamSubscription<NotificationEffect>? _effects;

  static DateTime _now() =>
      GetIt.I.isRegistered<Clock>() ? GetIt.I<Clock>().now() : clock.now();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<NotificationBloc>();
    if (bloc.state is NotificationInitial) {
      bloc.add(const LoadNotificationsEvent());
    }
    _effects = bloc.effects.listen(_onEffect);
  }

  @override
  void dispose() {
    unawaited(_effects?.cancel());
    super.dispose();
  }

  void _onEffect(NotificationEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case NotificationDeleted(:final notification):
        final bloc = context.read<NotificationBloc>();
        FpToast.show(
          context,
          message: 'Notification dismissed',
          actionLabel: 'Undo',
          onAction: () {
            playHaptic(null, HapticType.selection);
            bloc.add(AddNotificationEvent(notification));
          },
        );
      case NotificationFailed(:final message):
        playHaptic(null, HapticType.error);
        FpToast.show(context, message: message, kind: FpToastKind.error);
      case NotificationAdded():
        break;
    }
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _refresh() async {
    final bloc = context.read<NotificationBloc>();
    final settled = bloc.stream
        .firstWhere((s) => s is! NotificationLoading)
        .timeout(const Duration(seconds: 10), onTimeout: () => bloc.state);
    bloc.add(const LoadNotificationsEvent());
    await settled;
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final bloc = context.read<NotificationBloc>();
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: FpPressable(
          semanticLabel: 'Back',
          onPressed: () => _leave(context),
          child: Icon(Icons.arrow_back, color: c.textPrimary),
        ),
        title: Text('Notifications', style: fp.text.title),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, state) {
              final unread = state is NotificationContent
                  ? state.unreadCount
                  : 0;
              if (unread == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: FpSpacing.sm),
                child: FpPressable(
                  key: const ValueKey('notifications-mark-all'),
                  semanticLabel: 'Mark all $unread read',
                  onPressed: () {
                    playHaptic(null, HapticType.success);
                    bloc.add(const MarkAllNotificationsReadEvent());
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FpSpacing.sm,
                    ),
                    child: Text(
                      'MARK ALL READ',
                      style: fp.text.overline.copyWith(color: c.accent),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) => switch (state) {
          NotificationInitial() || NotificationLoading() => const _Skeleton(),
          NotificationError(:final message) => FpErrorState(
            title: 'Could not load notifications',
            message: message,
            onRetry: () => bloc.add(const LoadNotificationsEvent()),
          ),
          NotificationEmpty() => const FpPulse(
            key: ValueKey('notifications-empty'),
            maxScale: 1.03,
            child: FpEmptyState(
              icon: Icons.notifications_none,
              title: 'All caught up',
              message: 'Payments, cashback and reminders show up here.',
            ),
          ),
          NotificationContent(:final notifications) => FpRefreshIndicator(
            onRefresh: _refresh,
            child: _NotificationList(
              items: notifications,
              now: _now(),
              onTap: (n) {
                if (n.isRead) return;
                playHaptic(null, HapticType.selection);
                bloc.add(MarkNotificationReadEvent(n.id));
              },
              onDismiss: (n) => bloc.add(DeleteNotificationEvent(n.id)),
              onMarkRead: (n) => bloc.add(MarkNotificationReadEvent(n.id)),
            ),
          ),
        },
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.items,
    required this.now,
    required this.onTap,
    required this.onDismiss,
    required this.onMarkRead,
  });

  final List<NotificationItem> items;
  final DateTime now;
  final ValueChanged<NotificationItem> onTap;
  final ValueChanged<NotificationItem> onDismiss;
  final ValueChanged<NotificationItem> onMarkRead;

  @override
  Widget build(BuildContext context) {
    final staggered = math.min(items.length, NotificationsScreen.staggeredRows);
    final delays = FpStagger.delays(staggered);
    return ListView.separated(
      key: const ValueKey('notifications-scroll'),
      padding: const EdgeInsets.fromLTRB(
        FpSpacing.lg,
        FpSpacing.sm,
        FpSpacing.lg,
        FpSpacing.xxl,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: FpSpacing.sm),
      itemBuilder: (context, i) {
        final n = items[i];
        final row = _NotificationRow(
          key: ValueKey('notification-${n.id}'),
          item: n,
          now: now,
          onTap: () => onTap(n),
          onDismiss: () => onDismiss(n),
          onMarkRead: () => onMarkRead(n),
        );
        if (i >= staggered) return row;
        return FpEntrance(
          key: ValueKey('notification-entrance-${n.id}'),
          delay: delays[i],
          child: row,
        );
      },
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.now,
    required this.onTap,
    required this.onDismiss,
    required this.onMarkRead,
    super.key,
  });

  final NotificationItem item;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback onMarkRead;

  static IconData iconFor(NotificationType type) => switch (type) {
    NotificationType.cashback => Icons.savings_outlined,
    NotificationType.paymentReminder => Icons.alarm_outlined,
    NotificationType.profileUpdate => Icons.person_outline,
    NotificationType.paymentRequest => Icons.request_page_outlined,
    NotificationType.cardLinked => Icons.credit_card_outlined,
    NotificationType.billDue => Icons.receipt_long_outlined,
  };

  /// "Just now", "5 min ago", "3 h ago", "Yesterday" or `d MMM`.
  static String relativeTime(DateTime local, DateTime now) {
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (today.difference(day).inDays == 1) return 'Yesterday';
    return DateFormat('d MMM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final n = item;
    final when = relativeTime(n.localTime, now.toLocal());
    final label =
        '${n.title}, ${n.message}, $when'
        '${n.isRead ? '' : ', unread'}';
    return FpSwipeActionRow(
      semanticLabel: '$label, swipe left for actions',
      onTap: onTap,
      onDismissed: onDismiss,
      actions: [
        if (!n.isRead)
          FpSwipeAction(label: 'Read', icon: Icons.done, onPressed: onMarkRead),
        FpSwipeAction(
          label: 'Dismiss',
          icon: Icons.close,
          tone: FpSwipeActionTone.danger,
          onPressed: onDismiss,
        ),
      ],
      child: FpSurface(
        variant: n.isRead ? FpSurfaceVariant.flat : FpSurfaceVariant.raised,
        padding: const EdgeInsets.all(FpSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                border: Border.all(color: c.border),
              ),
              child: Icon(
                iconFor(n.type),
                size: 20,
                color: n.isRead ? c.textSecondary : c.accent,
              ),
            ),
            const SizedBox(width: FpSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: fp.text.body.copyWith(
                            fontWeight: n.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: FpSpacing.sm),
                      Text(when, style: fp.text.caption),
                    ],
                  ),
                  const SizedBox(height: FpSpacing.xs),
                  Text(
                    n.message,
                    style: fp.text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!n.isRead) ...[
              const SizedBox(width: FpSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: FpSpacing.xs),
                child: FpPulse(
                  key: ValueKey('unread-dot-${n.id}'),
                  maxScale: 1.6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return FpSkeletonGroup(
      child: ListView(
        key: const ValueKey('notifications-skeleton'),
        padding: const EdgeInsets.all(FpSpacing.lg),
        children: [
          for (var i = 0; i < 6; i++) ...[
            const FpSkeletonRow(),
            const SizedBox(height: FpSpacing.sm),
          ],
        ],
      ),
    );
  }
}
