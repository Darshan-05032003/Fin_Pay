import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/services/haptic_service.dart';
import 'package:fin_pay/widgets/animations/confetti_effect.dart';
import 'package:fin_pay/widgets/animations/delayed_animation.dart';
import 'package:fin_pay/widgets/animations/fade_in_animation.dart';
import 'package:flutter/material.dart';

class TransferSuccessScreen extends StatefulWidget {

  const TransferSuccessScreen({
    required this.recipientName, required this.amount, super.key,
  });
  final String recipientName;
  final String amount;

  @override
  State<TransferSuccessScreen> createState() => _TransferSuccessScreenState();
}

class _TransferSuccessScreenState extends State<TransferSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    
    // Start haptic feedback
    Future.delayed(const Duration(milliseconds: 300), HapticService.success);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConfettiEffect(
      autoPlay: true,
      child: Scaffold(
        backgroundColor: AppTheme.credPureBackground,
        appBar: AppBar(
          title: const Text('Review'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.credSurfaceCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Transform.rotate(
                            angle: _rotationAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppTheme.primaryGreen, AppTheme.credNeoPaccha.withOpacity(0.7)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.credOrangeSunshine.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check,
                                color: AppTheme.credSurfaceCard,
                                size: 70,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  const FadeInAnimation(
                    delay: Duration(milliseconds: 400),
                    child: Text(
                      'Transfer Success!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.credTextPrimary,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const FadeInAnimation(
                    delay: Duration(milliseconds: 500),
                    child: Text(
                      'Below is your withdraw summary',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.credTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transfer Destination',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.credTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DelayedAnimation(
                              delay: const Duration(milliseconds: 700),
                              curve: Curves.easeOutBack,
                              offset: const Offset(-20, 0),
                              child: _buildAvatar('A', 'Amir'),
                            ),
                            const SizedBox(width: 24),
                            const FadeInAnimation(
                              delay: Duration(milliseconds: 750),
                              child: Text(
                                'To',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.credOrangeSunshine,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            DelayedAnimation(
                              delay: const Duration(milliseconds: 800),
                              curve: Curves.easeOutBack,
                              offset: const Offset(20, 0),
                              child: _buildAvatar('K', widget.recipientName),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 900),
                    child: Column(
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.credTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DelayedAnimation(
                          delay: const Duration(milliseconds: 1000),
                          duration: const Duration(milliseconds: 1500),
                          child: RepaintBoundary(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: double.parse(widget.amount)),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Text(
                                '\$${value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.credOrangeSunshine,
                                  letterSpacing: 1,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInAnimation(
                    delay: const Duration(milliseconds: 1200),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Return to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String initial, String name) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryGreen, AppTheme.credNeoPaccha.withOpacity(0.7)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.credOrangeSunshine.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: AppTheme.credSurfaceCard,
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
}
