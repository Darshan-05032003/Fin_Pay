import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/models/card.dart' as models;
import 'package:fin_pay/services/haptic_service.dart';
import 'package:fin_pay/services/user_service.dart';
import 'package:fin_pay/widgets/animations/cred_button_press.dart';
import 'package:fin_pay/widgets/animations/cred_card_reveal.dart';
import 'package:fin_pay/widgets/animations/cred_slide_in.dart';
import 'package:fin_pay/widgets/animations/pulse_animation.dart';
import 'package:fin_pay/widgets/animations/spring_animation.dart';
import 'package:flutter/material.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _cardTypeController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expireController = TextEditingController();
  final _cvvController = TextEditingController();
  String _cardType = 'Select card type';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        title: const Text('Add New Card'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CredSlideIn(
              delay: const Duration(milliseconds: 100),
              child: CredCardReveal(
                duration: const Duration(milliseconds: 600),
                perspective: 0.0008,
                child: _buildCardPreview(),
              ),
            ),
            const SizedBox(height: 32),
            CredSlideIn(
              delay: const Duration(milliseconds: 200),
              child: CredCardReveal(
                duration: const Duration(milliseconds: 700),
                perspective: 0.0008,
                child: _buildCardTypeField(),
              ),
            ),
            const SizedBox(height: 16),
            CredSlideIn(
              delay: const Duration(milliseconds: 300),
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
                        child: TextField(
                          controller: _cardHolderController,
                          style: const TextStyle(color: AppTheme.credTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Card Holder Name',
                            hintText: 'Card holder name',
                            prefixIcon: Icon(Icons.person_outline, color: AppTheme.credTextSecondary),
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
            const SizedBox(height: 16),
            CredSlideIn(
              delay: const Duration(milliseconds: 400),
              child: CredCardReveal(
                duration: const Duration(milliseconds: 900),
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
                        child: TextField(
                          controller: _cardNumberController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppTheme.credTextPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Card Number',
                            hintText: 'Card number',
                            prefixIcon: Icon(Icons.credit_card, color: AppTheme.credTextSecondary),
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
            const SizedBox(height: 16),
            CredSlideIn(
              delay: const Duration(milliseconds: 500),
              child: Row(
                children: [
                  Expanded(
                    child: CredCardReveal(
                      duration: const Duration(milliseconds: 1000),
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
                              child: TextField(
                                controller: _expireController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: AppTheme.credTextPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'Expire',
                                  hintText: 'mm/yy',
                                  prefixIcon: Icon(Icons.calendar_today, color: AppTheme.credTextSecondary),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: CredCardReveal(
                      duration: const Duration(milliseconds: 1100),
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
                              child: TextField(
                                controller: _cvvController,
                                keyboardType: TextInputType.number,
                                obscureText: true,
                                style: const TextStyle(color: AppTheme.credTextPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'CVV',
                                  hintText: 'CVV',
                                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.credTextSecondary),
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
                ],
              ),
            ),
            const SizedBox(height: 32),
            CredSlideIn(
              delay: const Duration(milliseconds: 600),
              child: CredButtonPress(
                onTap: () async {
                  if (_cardType == 'Select card type' ||
                      _cardHolderController.text.trim().isEmpty ||
                      _cardNumberController.text.trim().isEmpty ||
                      _expireController.text.trim().isEmpty ||
                      _cvvController.text.trim().isEmpty) {
                    await HapticService.error();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all fields'),
                        backgroundColor: AppTheme.credError,
                      ),
                    );
                    return;
                  }

                  await HapticService.mediumImpact();

                  final cardType = _cardType == 'Visa'
                      ? models.CardType.visa
                      : _cardType == 'Mastercard'
                          ? models.CardType.mastercard
                          : models.CardType.amex;

                  final newCard = models.Card(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    cardNumber: _cardNumberController.text.trim(),
                    cardHolderName: _cardHolderController.text.trim(),
                    expireDate: _expireController.text.trim(),
                    cvv: _cvvController.text.trim(),
                    cardType: cardType,
                    balance: 0,
                  );

                  await UserService.addCard(newCard);
                  await HapticService.success();

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Card added successfully!'),
                        backgroundColor: AppTheme.credNeoPaccha,
                      ),
                    );
                  }
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
                        'Save New Card',
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

  Widget _buildCardPreview() {
    return PulseAnimation(
      minScale: 0.98,
      maxScale: 1.02,
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.credOrangeGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.credOrangeSunshine.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'VISA',
                style: TextStyle(
                  color: AppTheme.credWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _cardNumberController.text.isEmpty
                    ? '**** **** **** ****'
                    : _cardNumberController.text,
                style: const TextStyle(
                  color: AppTheme.credWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Card Holder',
                        style: TextStyle(
                          color: AppTheme.credWhite.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _cardHolderController.text.isEmpty
                            ? '********'
                            : _cardHolderController.text,
                        style: const TextStyle(
                          color: AppTheme.credWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expire',
                        style: TextStyle(
                          color: AppTheme.credWhite.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _expireController.text.isEmpty
                            ? 'mm/yy'
                            : _expireController.text,
                        style: const TextStyle(
                          color: AppTheme.credWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCardTypeField() {
    return CredButtonPress(
      onTap: () async {
        await HapticService.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.credSurfaceCard,
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
                CredButtonPress(
                  onTap: () async {
                    await HapticService.selection();
                    setState(() {
                      _cardType = 'Visa';
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.credPureBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.credit_card, color: AppTheme.credOrangeSunshine),
                        SizedBox(width: 16),
                        Text(
                          'Visa',
                          style: TextStyle(
                            color: AppTheme.credTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CredButtonPress(
                  onTap: () async {
                    await HapticService.selection();
                    setState(() {
                      _cardType = 'Mastercard';
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.credPureBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.credit_card, color: AppTheme.credOrangeSunshine),
                        SizedBox(width: 16),
                        Text(
                          'Mastercard',
                          style: TextStyle(
                            color: AppTheme.credTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CredButtonPress(
                  onTap: () async {
                    await HapticService.selection();
                    setState(() {
                      _cardType = 'American Express';
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.credPureBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.credit_card, color: AppTheme.credOrangeSunshine),
                        SizedBox(width: 16),
                        Text(
                          'American Express',
                          style: TextStyle(
                            color: AppTheme.credTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.credSurfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.credMediumGray.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.credOrangeGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.credOrangeSunshine.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.credit_card, color: AppTheme.credWhite, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _cardType,
                style: TextStyle(
                  color: _cardType == 'Select card type'
                      ? AppTheme.credTextSecondary
                      : AppTheme.credTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppTheme.credTextSecondary, size: 28),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cardTypeController.dispose();
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _expireController.dispose();
    _cvvController.dispose();
    super.dispose();
  }
}

