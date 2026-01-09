import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/theme.dart';
import '../../models/transaction.dart' as models;
import '../../models/user.dart';
import '../../presentation/providers/user_provider.dart';
import '../../presentation/providers/transaction_provider.dart';
import '../../services/haptic_service.dart';
import '../../widgets/animations/fade_in_animation.dart' as custom;
import '../../widgets/animations/staggered_list_animation.dart';
import '../../widgets/animations/pulse_animation.dart';
import '../../widgets/animations/skeleton_loader_full.dart';
import '../../widgets/animations/pull_to_refresh_custom.dart';
import '../../widgets/animations/ripple_effect.dart';
import '../../widgets/animations/icon_morph.dart';
import '../../widgets/animations/cred_number_counter.dart';
import '../../widgets/animations/cred_slide_in.dart';
import '../../widgets/animations/cred_button_press.dart';
import '../../widgets/animations/cred_card_reveal.dart';

class _FloatingActionButtonWithDelay extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FloatingActionButtonWithDelay({
    required this.child,
    required this.delay,
  });

  @override
  State<_FloatingActionButtonWithDelay> createState() => _FloatingActionButtonWithDelayState();
}

class _FloatingActionButtonWithDelayState extends State<_FloatingActionButtonWithDelay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() => _isVisible = true);
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _animation,
        child: widget.child,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, TransactionProvider>(
      builder: (context, userProvider, transactionProvider, child) {
        final user = userProvider.user;
        final recentTransactions = transactionProvider.recentTransactions;
        final isLoading = userProvider.isLoading || transactionProvider.isLoading;

        if (isLoading) {
          return Scaffold(
            backgroundColor: AppTheme.credBlack,
            body: _buildSkeletonLoader(),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.credBlack,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, user),
                Expanded(
                  child: CustomPullToRefresh(
                    onRefresh: () async {
                      await userProvider.loadUser();
                      await transactionProvider.loadTransactions();
                    },
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickActions(),
                      _buildPaymentList(context),
                      _buildPromoSection(),
                      _buildRecentTransactions(context, recentTransactions),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 0),
      floatingActionButton: CredSlideIn(
        delay: const Duration(milliseconds: 1000),
        offset: const Offset(0, 50),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        child: PulseAnimation(
          duration: const Duration(seconds: 2),
          minScale: 0.95,
          maxScale: 1.05,
          child: CredButtonPress(
            onTap: () async {
              await HapticService.mediumImpact();
              final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              Navigator.pushNamed(context, '/transfer').then((_) {
                userProvider.loadUser();
                transactionProvider.loadTransactions();
              });
            },
            child: FloatingActionButton(
              onPressed: null,
              backgroundColor: AppTheme.credPurple,
              elevation: 12,
              child: IconMorph(
                startIcon: Icons.send,
                endIcon: Icons.send,
                color: AppTheme.credWhite,
                size: 28,
                animateOnTap: true,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, User? user) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final balance = userProvider.balance;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    final firstName = user?.fullName.split(' ').first ?? 'User';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: BoxDecoration(
        gradient: AppTheme.credPurpleGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          custom.FadeInAnimation(
            delay: const Duration(milliseconds: 100),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RepaintBoundary(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(-20 * (1 - value), 0),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            '$greeting.',
                            style: const TextStyle(
                              color: AppTheme.credTextSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 4),
                custom.FadeInAnimation(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    'Hello $firstName',
                    style: const TextStyle(
                      color: AppTheme.credWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RippleEffect(
                      borderRadius: 20,
                      onTap: () async {
                        await HapticService.lightImpact();
                        Navigator.pushNamed(context, '/notifications');
                      },
                      child: IconButton(
                        icon: IconMorph(
                          startIcon: Icons.notifications_outlined,
                          endIcon: Icons.notifications,
                          color: AppTheme.credGray,
                          size: 24,
                          animateOnTap: false,
                        ),
                        onPressed: null,
                      ),
                    ),
                    RippleEffect(
                      borderRadius: 20,
                      onTap: () async {
                        await HapticService.lightImpact();
                        Navigator.pushNamed(context, '/profile');
                      },
                      child: IconButton(
                        icon: IconMorph(
                          startIcon: Icons.settings_outlined,
                          endIcon: Icons.settings,
                          color: AppTheme.credGray,
                          size: 24,
                          animateOnTap: false,
                        ),
                        onPressed: null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          custom.FadeInAnimation(
            delay: const Duration(milliseconds: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                          const Text(
                            'Available Balance',
                            style: TextStyle(
                              color: AppTheme.credTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CredNumberCounter(
                            value: balance,
                            prefix: '\$',
                            decimalPlaces: 2,
                            duration: const Duration(milliseconds: 1500),
                            style: const TextStyle(
                              color: AppTheme.credWhite,
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
              ],
            ),
          ),
          const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionIcon(Icons.directions_car, 'Transport', 0),
                _buildQuickActionIcon(Icons.shopping_cart, 'Shopping', 1),
                _buildQuickActionIcon(Icons.card_giftcard, 'Gift', 2),
                _buildQuickActionIcon(Icons.account_balance, 'Finance', 3),
                _buildQuickActionIcon(Icons.add, 'More', 4),
              ],
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildQuickActionIcon(IconData icon, String label, int index) {
    return CredSlideIn(
      delay: Duration(milliseconds: 400 + (index * 50)),
      offset: const Offset(0, 30),
      child: CredButtonPress(
        onTap: () async {
          await HapticService.selection();
          _handleQuickActionTap(label);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseAnimation(
              duration: const Duration(seconds: 2),
              minScale: 0.98,
              maxScale: 1.02,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.credGray,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.credLightGray.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.credPurple.withOpacity(0.1),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(icon, color: AppTheme.credWhite, size: 24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.credTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuickActionTap(String label) {
    final context = this.context;
    switch (label) {
      case 'Transport':
        _showComingSoonSnackBar(context, 'Transport booking coming soon!');
        break;
      case 'Shopping':
        _showComingSoonSnackBar(context, 'Shopping features coming soon!');
        break;
      case 'Gift':
        _showComingSoonSnackBar(context, 'Gift cards coming soon!');
        break;
      case 'Finance':
        Navigator.pushNamed(context, '/statistics');
        break;
      case 'More':
        _showMoreOptions(context);
        break;
    }
  }

  void _showComingSoonSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.credGray,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.credGray,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.credTextTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildMoreOption(Icons.qr_code, 'Scan QR Code', () {
              Navigator.pop(context);
              _showComingSoonSnackBar(context, 'QR Code scanner coming soon!');
            }),
            _buildMoreOption(Icons.request_quote, 'Request Money', () {
              Navigator.pop(context);
              _showComingSoonSnackBar(context, 'Request money feature coming soon!');
            }),
            _buildMoreOption(Icons.account_balance_wallet, 'Top Up', () {
              Navigator.pop(context);
              _showComingSoonSnackBar(context, 'Top up feature coming soon!');
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.credPurple),
      title: Text(label, style: const TextStyle(color: AppTheme.credTextPrimary)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.credTextSecondary),
      onTap: () async {
        await HapticService.selection();
        onTap();
      },
    );
  }

  Widget _buildQuickActions() {
    return const SizedBox(height: 16);
  }

  Widget _buildPaymentList(BuildContext context) {
    return custom.FadeInAnimation(
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Pay',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.credTextPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _buildAnimatedPaymentItem(Icons.wifi, 'Internet', AppTheme.credOrange, 0),
                _buildAnimatedPaymentItem(Icons.bolt, 'Electricity', AppTheme.credRed, 1),
                _buildAnimatedPaymentItem(Icons.phone, 'Mobile', AppTheme.credPurple, 2),
                _buildAnimatedPaymentItem(Icons.water_drop, 'Water', AppTheme.credBlue, 3),
                _buildAnimatedPaymentItem(Icons.local_gas_station, 'Gas', AppTheme.credGreen, 4),
                _buildAnimatedPaymentItem(Icons.tv, 'TV', AppTheme.credPurpleLight, 5),
                _buildAnimatedPaymentItem(Icons.store, 'Merchant', AppTheme.credPurple, 6),
                _buildAnimatedPaymentItem(Icons.more_horiz, 'More', AppTheme.credTextSecondary, 7),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedPaymentItem(IconData icon, String label, Color color, int index) {
    return CredSlideIn(
      delay: Duration(milliseconds: 500 + (index * 60)),
      offset: const Offset(0, 30),
      duration: Duration(milliseconds: 500 + (index * 50)),
      curve: Curves.easeOutBack,
      child: CredCardReveal(
        duration: Duration(milliseconds: 400 + (index * 50)),
        child: _buildPaymentItem(icon, label, color),
      ),
    );
  }

  Widget _buildPaymentItem(IconData icon, String label, Color color) {
    return CredButtonPress(
      onTap: () async {
        await HapticService.selection();
        _handlePaymentItemTap(label);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.credGray,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.credLightGray.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.credTextSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _handlePaymentItemTap(String label) {
    final context = this.context;
    switch (label) {
      case 'Internet':
      case 'Electricity':
      case 'Mobile':
      case 'Water':
      case 'Gas':
      case 'TV':
        _navigateToBillPayment(context, label);
        break;
      case 'Merchant':
        _showComingSoonSnackBar(context, 'Merchant payments coming soon!');
        break;
      case 'More':
        _showMorePaymentOptions(context);
        break;
    }
  }

  void _navigateToBillPayment(BuildContext context, String billType) {
    Navigator.pushNamed(
      context,
      '/transfer',
      arguments: {'billType': billType},
    );
  }

  void _showMorePaymentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.credGray,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.credTextTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'More Payment Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.credTextPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _buildMoreOption(Icons.school, 'Education', () {
              Navigator.pop(context);
              _navigateToBillPayment(context, 'Education');
            }),
            _buildMoreOption(Icons.local_hospital, 'Healthcare', () {
              Navigator.pop(context);
              _navigateToBillPayment(context, 'Healthcare');
            }),
            _buildMoreOption(Icons.home, 'Rent', () {
              Navigator.pop(context);
              _navigateToBillPayment(context, 'Rent');
            }),
            _buildMoreOption(Icons.subscriptions, 'Subscriptions', () {
              Navigator.pop(context);
              _navigateToBillPayment(context, 'Subscriptions');
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSection() {
    return CredSlideIn(
      delay: const Duration(milliseconds: 600),
      offset: const Offset(0, 40),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CredCardReveal(
          duration: const Duration(milliseconds: 600),
          perspective: 0.0008,
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: AppTheme.credPurpleGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.credPurple.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CredSlideIn(
                  delay: const Duration(milliseconds: 100),
                  offset: const Offset(-20, 0),
                  child: const Text(
                    "Today's Promo",
                    style: TextStyle(
                      color: AppTheme.credWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PulseAnimation(
                  duration: const Duration(seconds: 2),
                  minScale: 0.98,
                  maxScale: 1.02,
                  child: const Text(
                    '40%',
                    style: TextStyle(
                      color: AppTheme.credWhite,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CredSlideIn(
                  delay: const Duration(milliseconds: 200),
                  offset: const Offset(0, 10),
                  child: const Text(
                    'Get discount for every top-up, transfer and payment',
                    style: TextStyle(
                      color: AppTheme.credWhite,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context, List<models.Transaction> transactions) {
    return CredSlideIn(
      delay: const Duration(milliseconds: 800),
      offset: const Offset(0, 30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CredSlideIn(
              delay: const Duration(milliseconds: 850),
              offset: const Offset(-20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Transaction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.credTextPrimary,
                    ),
                  ),
                  CredButtonPress(
                    onTap: () {
                      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      Navigator.pushNamed(context, '/transactions').then((_) {
                        userProvider.loadUser();
                        transactionProvider.loadTransactions();
                      });
                    },
                    child: TextButton(
                      onPressed: null,
                      child: const Text(
                        'See All',
                        style: TextStyle(color: AppTheme.credPurple),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No recent transactions',
                  style: TextStyle(
                    color: AppTheme.credTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...transactions.asMap().entries.map((entry) {
              final index = entry.key;
              final transaction = entry.value;
              return StaggeredListAnimation(
                index: index,
                child: _buildTransactionItem(transaction),
              );
            }),
          const SizedBox(height: 16),
        ],
      ),
    ),
    );
  }

  Widget _buildTransactionItem(models.Transaction transaction) {
    return CredButtonPress(
      onTap: () async {
        await HapticService.lightImpact();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.credGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.credLightGray.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (transaction.type == models.TransactionType.receiveMoney || transaction.amount > 0
                        ? AppTheme.credGreen
                        : AppTheme.credRed).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  transaction.icon,
                  style: TextStyle(
                    color: transaction.type == models.TransactionType.receiveMoney || transaction.amount > 0
                        ? AppTheme.credGreen
                        : AppTheme.credRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.credTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.credTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${transaction.amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: transaction.amount < 0 ? AppTheme.credRed : AppTheme.credGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (transaction.amount < 0 ? AppTheme.credRed : AppTheme.credGreen).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    transaction.amount < 0 ? 'Payment' : 'Received',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: transaction.amount < 0 ? AppTheme.credRed : AppTheme.credGreen,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppTheme.credBlack,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            SkeletonLoader(width: double.infinity, height: 180, borderRadius: BorderRadius.circular(24)),
            const SizedBox(height: 24),
            const SkeletonList(itemCount: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.credGray,
        border: Border(
          top: BorderSide(
            color: AppTheme.credLightGray.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.credGray,
        selectedItemColor: AppTheme.credPurple,
        unselectedItemColor: AppTheme.credTextTertiary,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        onTap: (index) async {
          await HapticService.selection();
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/statistics');
          } else if (index == 2) {
            Navigator.pushReplacementNamed(context, '/cards');
          } else if (index == 3) {
            Navigator.pushReplacementNamed(context, '/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card),
            label: 'My Cards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
