import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/services/haptic_service.dart';
import 'package:fin_pay/services/user_service.dart';
import 'package:fin_pay/widgets/animations/cred_button_press.dart';
import 'package:fin_pay/widgets/animations/cred_card_reveal.dart';
import 'package:fin_pay/widgets/animations/cred_slide_in.dart';
import 'package:fin_pay/widgets/animations/fade_in_animation.dart' as custom;
import 'package:fin_pay/widgets/animations/pull_to_refresh_custom.dart';
import 'package:fin_pay/widgets/animations/skeleton_loader_full.dart';
import 'package:fin_pay/widgets/animations/swipe_to_dismiss.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _allNotifications = [];
  List<NotificationItem> _todayNotifications = [];
  List<NotificationItem> _yesterdayNotifications = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifications = await UserService.getNotifications();
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final today = notifications.where((n) => n.time.isAfter(todayStart)).toList();
    final yesterday = notifications.where((n) {
      return n.time.isAfter(yesterdayStart) && n.time.isBefore(todayStart);
    }).toList();

    setState(() {
      _allNotifications = notifications;
      _todayNotifications = today;
      _yesterdayNotifications = yesterday;
      _isLoading = false;
    });
  }

  List<NotificationItem> get _filteredToday {
    if (_searchQuery.isEmpty) return _todayNotifications;
    return _todayNotifications.where((n) => 
      n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      n.message.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  List<NotificationItem> get _filteredYesterday {
    if (_searchQuery.isEmpty) return _yesterdayNotifications;
    return _yesterdayNotifications.where((n) => 
      n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      n.message.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await HapticService.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          CredSlideIn(
            delay: const Duration(milliseconds: 100),
            offset: const Offset(0, 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: CredCardReveal(
                      duration: const Duration(milliseconds: 400),
                      perspective: 0.0006,
                      child: Focus(
                        child: Builder(
                          builder: (context) {
                            final hasFocus = Focus.of(context).hasFocus;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: AppTheme.credSurfaceCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: hasFocus
                                      ? AppTheme.credOrangeSunshine
                                      : AppTheme.credMediumGray.withOpacity(0.2),
                                  width: hasFocus ? 2 : 1,
                                ),
                              ),
                              child: TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                  HapticService.selection();
                                },
                                style: const TextStyle(color: AppTheme.credTextPrimary),
                                decoration: const InputDecoration(
                                  hintText: 'Search notifications',
                                  hintStyle: TextStyle(color: AppTheme.credTextSecondary),
                                  prefixIcon: Icon(Icons.search, color: AppTheme.credTextSecondary),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CredSlideIn(
                    delay: const Duration(milliseconds: 150),
                    offset: const Offset(20, 0),
                    child: CredButtonPress(
                      onTap: () async {
                        await HapticService.mediumImpact();
                      },
                      child: CredCardReveal(
                        perspective: 0.0006,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppTheme.credOrangeGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.credOrangeSunshine.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.filter_list, color: AppTheme.credWhite, size: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const SkeletonList()
                : _allNotifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: AppTheme.credTextSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.credTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CustomPullToRefresh(
                        onRefresh: _loadNotifications,
                        child: AnimationLimiter(
                          child: ListView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (_filteredToday.isNotEmpty) ...[
                                CredSlideIn(
                                  delay: const Duration(milliseconds: 250),
                                  offset: const Offset(0, 20),
                                  child: _buildSectionHeader('Today'),
                                ),
                                ..._filteredToday.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final notification = entry.value;
                                  return CredSlideIn(
                                    delay: Duration(milliseconds: 300 + (index * 50)),
                                    child: CredCardReveal(
                                      duration: Duration(milliseconds: 400 + (index * 30)),
                                      perspective: 0.0006,
                                      child: SwipeToDismiss(
                                        uniqueKey: notification.id,
                                        onDismiss: () async {
                                          await HapticService.mediumImpact();
                                          setState(() {
                                            _allNotifications.removeWhere((n) => n.id == notification.id);
                                            _todayNotifications.removeWhere((n) => n.id == notification.id);
                                          });
                                          await UserService.saveNotifications(_allNotifications);
                                        },
                                        child: CredButtonPress(
                                          onTap: () async {
                                            await HapticService.lightImpact();
                                          },
                                          child: _buildNotificationItem(notification),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 24),
                              ],
                              if (_filteredYesterday.isNotEmpty) ...[
                                CredSlideIn(
                                  delay: Duration(milliseconds: 250 + (_filteredToday.length * 50)),
                                  offset: const Offset(0, 20),
                                  child: _buildSectionHeader('Yesterday'),
                                ),
                                ..._filteredYesterday.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final notification = entry.value;
                                  return AnimationConfiguration.staggeredList(
                                    position: index + _filteredToday.length,
                                    duration: const Duration(milliseconds: 375),
                                    child: SlideAnimation(
                                      verticalOffset: 50,
                                      child: custom.FadeInAnimation(
                                        child: SwipeToDismiss(
                                          uniqueKey: notification.id,
                                          onDismiss: () async {
                                            await HapticService.mediumImpact();
                                            setState(() {
                                              _allNotifications.removeWhere((n) => n.id == notification.id);
                                              _yesterdayNotifications.removeWhere((n) => n.id == notification.id);
                                            });
                                            await UserService.saveNotifications(_allNotifications);
                                          },
                                          child: _buildNotificationItem(notification),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.credTextPrimary,
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    IconData icon;
    const iconColor = AppTheme.primaryGreen;

    switch (notification.type) {
      case NotificationType.cashback:
        icon = Icons.attach_money;
      case NotificationType.paymentReminder:
        icon = Icons.access_time;
      case NotificationType.profileUpdate:
        icon = Icons.person;
      case NotificationType.paymentRequest:
        icon = Icons.request_quote;
      case NotificationType.cardLinked:
        icon = Icons.credit_card;
      case NotificationType.billDue:
        icon = Icons.receipt;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.credSurfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.credTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.credTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _formatTime(notification.time),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.credTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}
