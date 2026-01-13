import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../constants/theme.dart';
import '../../models/transaction.dart';
import '../../services/user_service.dart';
import '../../services/haptic_service.dart';
import '../../widgets/animations/fade_in_animation.dart' as custom;
import '../../widgets/animations/skeleton_loader_full.dart';
import '../../widgets/animations/pull_to_refresh_custom.dart';
import '../../widgets/animations/cred_slide_in.dart';
import '../../widgets/animations/cred_button_press.dart';
import '../../widgets/animations/cred_card_reveal.dart';
import '../../widgets/animations/cred_number_counter.dart';
import '../../widgets/animations/pulse_animation.dart';
import '../../widgets/cred_bottom_navigation_bar.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  double _totalSpending = 0.0;
  double _income = 0.0;
  double _expenses = 0.0;
  List<Transaction> _recentTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final transactions = await UserService.getTransactions();
    
    double totalSpending = 0.0;
    double income = 0.0;
    double expenses = 0.0;

    for (var transaction in transactions) {
      if (transaction.amount < 0) {
        expenses += transaction.amount.abs();
        totalSpending += transaction.amount.abs();
      } else {
        income += transaction.amount;
      }
    }

    setState(() {
      _totalSpending = totalSpending;
      _income = income;
      _expenses = expenses;
      _recentTransactions = transactions.take(1).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        title: const Text('Statics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await HapticService.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: _isLoading
          ? const SkeletonList(itemCount: 5)
          : CustomPullToRefresh(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: AnimationLimiter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  CredSlideIn(
                    delay: const Duration(milliseconds: 100),
                    offset: const Offset(0, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(
                          child: Text(
                            'Total Spending',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.credTextPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        CredButtonPress(
                          onTap: () async {
                            await HapticService.mediumImpact();
                          },
                          child: CredCardReveal(
                            duration: const Duration(milliseconds: 400),
                            perspective: 0.0006,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.credSurfaceCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.credMediumGray.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Monthly',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.credTextPrimary,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down, size: 20, color: AppTheme.credTextPrimary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CredSlideIn(
                    delay: const Duration(milliseconds: 200),
                    offset: const Offset(0, 30),
                    child: CredNumberCounter(
                      value: _totalSpending,
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.credOrangeSunshine,
                        letterSpacing: -1,
                      ),
                      prefix: '\$',
                    ),
                  ),
                  const SizedBox(height: 32),
                  CredSlideIn(
                    delay: const Duration(milliseconds: 300),
                    offset: const Offset(0, 40),
                    child: CredCardReveal(
                      duration: const Duration(milliseconds: 600),
                      perspective: 0.0008,
                      child: _buildChart(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  CredSlideIn(
                    delay: const Duration(milliseconds: 400),
                    offset: const Offset(0, 30),
                    child: Row(
                      children: [
                        Expanded(
                          child: CredSlideIn(
                            delay: const Duration(milliseconds: 450),
                            offset: const Offset(-20, 0),
                            child: _buildStatCard(Icons.account_balance_wallet, 'Income', _income),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CredSlideIn(
                            delay: const Duration(milliseconds: 500),
                            offset: const Offset(20, 0),
                            child: _buildStatCard(Icons.shopping_cart, 'Expenses', _expenses),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimationConfiguration.staggeredList(
                    position: 3,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: custom.FadeInAnimation(
                        child: const Text(
                          'Recent Transaction',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.credTextPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_recentTransactions.isEmpty)
                    AnimationConfiguration.staggeredList(
                      position: 4,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: custom.FadeInAnimation(
                          child: const Padding(
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
                          ),
                        ),
                      ),
                    )
                  else
                    AnimationConfiguration.staggeredList(
                      position: 4,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: custom.FadeInAnimation(
                          child: _buildRecentTransaction(_recentTransactions.first),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 1),
    );
  }

  Widget _buildChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.credSurfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('10K', style: TextStyle(fontSize: 12, color: AppTheme.credTextSecondary)),
              Text('20K', style: TextStyle(fontSize: 12, color: AppTheme.credTextSecondary)),
              Text('30K', style: TextStyle(fontSize: 12, color: AppTheme.credTextSecondary)),
              Text('40K', style: TextStyle(fontSize: 12, color: AppTheme.credTextSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = constraints.maxHeight - 25; // Reserve space for label and spacing
                final maxBarHeight = 160.0;
                final scaleFactor = maxHeight / maxBarHeight;
                
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBar((80 * scaleFactor).clamp(0.0, maxHeight), 'Sep'),
                    _buildBar((120 * scaleFactor).clamp(0.0, maxHeight), 'Oct'),
                    _buildBar((140 * scaleFactor).clamp(0.0, maxHeight), 'Nov'),
                    _buildBar((160 * scaleFactor).clamp(0.0, maxHeight), 'Dec'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double height, String label) {
    return Flexible(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: height.clamp(0.0, double.infinity),
            decoration: BoxDecoration(
              color: AppTheme.credOrangeSunshine,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.credTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, double value) {
    return CredCardReveal(
      duration: const Duration(milliseconds: 500),
      perspective: 0.0006,
      child: CredButtonPress(
        onTap: () async {
          await HapticService.lightImpact();
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.credSurfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.credMediumGray.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PulseAnimation(
                duration: const Duration(seconds: 2),
                minScale: 0.98,
                maxScale: 1.02,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.credOrangeGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.credOrangeSunshine.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: AppTheme.credWhite, size: 24),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.credTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              CredNumberCounter(
                value: value,
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.credOrangeSunshine,
                  letterSpacing: -0.5,
                ),
                prefix: '\$',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransaction(Transaction transaction) {
    return Container(
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
              color: AppTheme.credError.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                transaction.icon,
                style: const TextStyle(
                  color: AppTheme.credError,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.credError,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.credError.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Payment',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.credError,
                  ),
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildBottomNavigationBar(BuildContext context, int currentIndex) {
    return CredBottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
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
    );
  }
}
