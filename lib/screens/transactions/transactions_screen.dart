import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../constants/theme.dart';
import '../../models/transaction.dart';
import '../../services/user_service.dart';
import '../../services/haptic_service.dart';
import '../../widgets/animations/swipe_to_dismiss.dart';
import '../../widgets/animations/skeleton_loader_full.dart';
import '../../widgets/animations/pull_to_refresh_custom.dart';
import '../../widgets/animations/cred_slide_in.dart';
import '../../widgets/animations/cred_button_press.dart';
import '../../widgets/animations/cred_card_reveal.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactions = await UserService.getTransactions();
    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  List<Transaction> get _filteredTransactions {
    if (_searchQuery.isEmpty) {
      return _transactions;
    }
    return _transactions.where((transaction) {
      return transaction.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (transaction.recipient?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        title: const Text('Transaction'),
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
              padding: const EdgeInsets.all(16.0),
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
                                  hintText: 'Search transaction...',
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
                        duration: const Duration(milliseconds: 400),
                        perspective: 0.0006,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.credSurfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.credMediumGray.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(Icons.filter_list, color: AppTheme.credOrangeSunshine, size: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CredSlideIn(
                    delay: const Duration(milliseconds: 200),
                    offset: const Offset(20, 0),
                    child: CredButtonPress(
                      onTap: () async {
                        await HapticService.mediumImpact();
                      },
                      child: CredCardReveal(
                        duration: const Duration(milliseconds: 500),
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
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_drop_down, color: AppTheme.credWhite, size: 24),
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
                ? const SkeletonList(itemCount: 5)
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: AppTheme.credTextSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No transactions yet'
                                  : 'No transactions found',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.credTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CustomPullToRefresh(
                        onRefresh: _loadTransactions,
                        child: AnimationLimiter(
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredTransactions.length,
                            itemBuilder: (context, index) {
                              final transaction = _filteredTransactions[index];
                              return CredSlideIn(
                                delay: Duration(milliseconds: 300 + (index * 50)),
                                offset: const Offset(0, 30),
                                child: CredCardReveal(
                                  duration: Duration(milliseconds: 400 + (index * 30)),
                                  perspective: 0.0006,
                                  child: SwipeToDismiss(
                                    uniqueKey: transaction.id,
                                    onDismiss: () async {
                                      await HapticService.mediumImpact();
                                      setState(() {
                                        _transactions.removeWhere((t) => t.id == transaction.id);
                                      });
                                      await UserService.saveTransactions(_transactions);
                                    },
                                    child: CredButtonPress(
                                      onTap: () async {
                                        await HapticService.lightImpact();
                                      },
                                      child: _buildTransactionItem(transaction),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isPayment = transaction.amount < 0;
    final iconColor = isPayment ? AppTheme.credError : AppTheme.credNeoPaccha;
    final tagColor = isPayment ? AppTheme.credError : AppTheme.credNeoPaccha;
    final tagText = isPayment ? 'Payment' : 'Received';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.credSurfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.credMediumGray.withOpacity(0.2),
          width: 1,
        ),
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
            child: Center(
              child: Text(
                transaction.icon,
                style: TextStyle(
                  color: iconColor,
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
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.credTextTertiary,
                    fontWeight: FontWeight.w500,
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
                  color: isPayment ? AppTheme.credError : AppTheme.credNeoPaccha,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tagText,
                  style: TextStyle(
                    fontSize: 10,
                    color: tagColor,
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
}
