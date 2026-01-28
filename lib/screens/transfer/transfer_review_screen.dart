import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/services/haptic_service.dart';
import 'package:fin_pay/services/user_service.dart';
import 'package:fin_pay/widgets/animations/cred_button_press.dart';
import 'package:fin_pay/widgets/animations/cred_card_reveal.dart';
import 'package:fin_pay/widgets/animations/cred_slide_in.dart';
import 'package:fin_pay/widgets/animations/draggable_card.dart';
import 'package:fin_pay/widgets/animations/pulse_animation.dart';
import 'package:fin_pay/widgets/animations/spring_animation.dart';
import 'package:flutter/material.dart';

class TransferReviewScreen extends StatelessWidget {

  const TransferReviewScreen({
    required this.recipientName, required this.recipientAccount, required this.amount, super.key,
  });
  final String recipientName;
  final String recipientAccount;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        title: const Text('Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await HapticService.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CredSlideIn(
              delay: Duration(milliseconds: 100),
              offset: Offset(0, 20),
              child: Text(
                'Confirm To Transfer Money',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.credTextPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            CredSlideIn(
              delay: const Duration(milliseconds: 200),
              child: CredCardReveal(
                duration: const Duration(milliseconds: 600),
                perspective: 0.0008,
                child: DraggableCard(
                  onSwipeLeft: () {},
                  onSwipeRight: () {},
                  child: _buildSenderRecipient(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            CredSlideIn(
              delay: const Duration(milliseconds: 300),
              child: CredCardReveal(
                duration: const Duration(milliseconds: 700),
                perspective: 0.0008,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.credSurfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.credMediumGray.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Transaction ID', 'TXN 30342303'),
                      const Divider(color: AppTheme.credMediumGray, thickness: 0.5),
                      _buildDetailRow('Recipient', recipientName),
                      const Divider(color: AppTheme.credMediumGray, thickness: 0.5),
                      _buildDetailRow('Amount', '\$$amount'),
                      const Divider(color: AppTheme.credMediumGray, thickness: 0.5),
                      _buildDetailRow('Fees', r'$0.00'),
                      const Divider(color: AppTheme.credMediumGray, thickness: 0.5),
                      _buildDetailRow(
                        'Total Amount',
                        '\$$amount',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            CredSlideIn(
              delay: const Duration(milliseconds: 400),
              child: CredCardReveal(
                duration: const Duration(milliseconds: 800),
                perspective: 0.0008,
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
                        child: const TextField(
                          maxLines: 3,
                          maxLength: 50,
                          style: TextStyle(color: AppTheme.credTextPrimary),
                          decoration: InputDecoration(
                            labelText: 'Reference',
                            hintText: 'Tap to add a note',
                            counterText: '0/50',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(20),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            CredSlideIn(
              delay: const Duration(milliseconds: 500),
              child: CredButtonPress(
                onTap: () async {
                    final transferAmount = double.tryParse(amount);
                    if (transferAmount == null || transferAmount <= 0) {
                      await HapticService.error();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid amount'),
                          backgroundColor: AppTheme.red,
                        ),
                      );
                      return;
                    }

                    final currentBalance = await UserService.getBalance();
                    if (transferAmount > currentBalance) {
                      await HapticService.error();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Insufficient balance'),
                          backgroundColor: AppTheme.red,
                        ),
                      );
                      return;
                    }

                    await HapticService.heavyImpact();

                    // Create transaction
                    final transaction = Transaction(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: 'Transfer to $recipientName',
                      amount: -transferAmount,
                      date: DateTime.now(),
                      type: TransactionType.sendMoney,
                      icon: recipientName[0].toUpperCase(),
                      recipient: recipientName,
                    );

                    await UserService.addTransaction(transaction);

                    // Add notification
                    final notification = NotificationItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: 'Transfer Successful!',
                      message: 'You transferred \$$amount to $recipientName',
                      time: DateTime.now(),
                      type: NotificationType.paymentRequest,
                    );
                    await UserService.addNotification(notification);

                    Navigator.pushReplacementNamed(
                      context,
                      '/transfer-success',
                      arguments: {
                        'recipientName': recipientName,
                        'amount': amount,
                      },
                    );
                  },
                  child: SpringAnimation(
                    startOffset: const Offset(0, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.credOrangeGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.credOrangeSunshine.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: const Center(
                        child: Text(
                          'Confirm & Transfer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.credWhite,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderRecipient() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CredSlideIn(
          delay: const Duration(milliseconds: 250),
          offset: const Offset(-20, 0),
          child: _buildAvatar('A', 'Amir'),
        ),
        const SizedBox(width: 16),
        const CredSlideIn(
          delay: Duration(milliseconds: 300),
          offset: Offset(0, 10),
          child: Text(
            'To',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.credTextSecondary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        CredSlideIn(
          delay: const Duration(milliseconds: 350),
          offset: const Offset(20, 0),
          child: _buildAvatar(recipientName[0].toUpperCase(), recipientName),
        ),
      ],
    );
  }

  Widget _buildAvatar(String initial, String name) {
    return Column(
      children: [
        PulseAnimation(
          minScale: 0.98,
          maxScale: 1.02,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppTheme.credOrangeGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.credOrangeSunshine.withOpacity(0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppTheme.credWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.credTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.credTextSecondary,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              color: isTotal ? AppTheme.credOrangeSunshine : AppTheme.credTextPrimary,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

