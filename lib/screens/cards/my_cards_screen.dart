import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/card.dart' as models;
import '../../services/user_service.dart';
import '../../widgets/animations/staggered_list_animation.dart';
import '../../widgets/animations/card_3d_flip.dart';
import '../../widgets/animations/ripple_effect.dart';
import '../../widgets/animations/fade_in_animation.dart';
import '../../services/haptic_service.dart';
import '../../widgets/cred_bottom_navigation_bar.dart';
import 'add_card_screen.dart';

class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  List<models.Card> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final cards = await UserService.getCards();
    setState(() {
      _cards = cards;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        title: const Text('My Card'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_cards.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No cards added yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.credTextSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._cards.asMap().entries.map((entry) {
                      final index = entry.key;
                      final card = entry.value;
                      return StaggeredListAnimation(
                        index: index,
                        duration: const Duration(milliseconds: 400),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Card3DFlip(
                            flipOnTap: true,
                            perspective: 0.0006,
                            frontChild: _buildCardDisplay(card),
                            backChild: _buildCardBack(card),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 300),
                    child: RippleEffect(
                      borderRadius: 12,
                      onTap: () async {
                        await HapticService.mediumImpact();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddCardScreen(),
                          ),
                        );
                        _loadCards();
                      },
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.credOrangeSunshine.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ElevatedButton(
                                onPressed: null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: AppTheme.credOrangeSunshine,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Add New Card'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_cards.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildCardDetails(_cards.first),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 2),
    );
  }

  Widget _buildCardDisplay(models.Card card) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Opacity(
              opacity: value,
              child: Container(
              height: 200,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.credOrangeGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.credOrangeSunshine.withOpacity(0.4 * value),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: Offset(0, 10 * value),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        card.cardType == models.CardType.visa
                            ? 'VISA'
                            : card.cardType == models.CardType.mastercard
                                ? 'MASTERCARD'
                                : 'AMEX',
                        style: const TextStyle(
                          color: AppTheme.credSurfaceCard,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.maskedNumber,
                        style: const TextStyle(
                          color: AppTheme.credSurfaceCard,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Card Holder',
                                  style: TextStyle(
                                    color: AppTheme.credSurfaceCard.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  card.cardHolderName,
                                  style: const TextStyle(
                                    color: AppTheme.credSurfaceCard,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Expire',
                                  style: TextStyle(
                                    color: AppTheme.credSurfaceCard.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  card.expireDate,
                                  style: const TextStyle(
                                    color: AppTheme.credSurfaceCard,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildCardBack(models.Card card) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.credOrangeSunshine.withOpacity(0.5), AppTheme.credOrangeSunshine],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 20),
          Container(
            height: 40,
            width: double.infinity,
            color: Colors.black.withOpacity(0.3),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  card.cvv,
                  style: const TextStyle(
                    color: AppTheme.credSurfaceCard,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    card.cardHolderName.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.credSurfaceCard,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    card.expireDate,
                    style: const TextStyle(
                      color: AppTheme.credSurfaceCard,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardDetails(models.Card card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.credSurfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Card Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.credTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Balance', '\$${card.balance.toStringAsFixed(2)}'),
          const Divider(),
          _buildDetailRow('Card Type', card.cardType.toString().split('.').last.toUpperCase()),
          const Divider(),
          _buildDetailRow('Card Holder Name', card.cardHolderName),
          const Divider(),
          _buildDetailRow('Card Number', card.maskedNumber),
          const Divider(),
          _buildDetailRow('Expire In', card.expireDate),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.credTextSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.credTextPrimary,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
