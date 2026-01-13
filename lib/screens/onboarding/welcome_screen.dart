import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../widgets/animations/fade_in_animation.dart';
import '../../widgets/animations/pulse_animation.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    PulseAnimation(
                      duration: const Duration(seconds: 2),
                      minScale: 0.98,
                      maxScale: 1.02,
                      child: const Text(
                        'FinPay',
                        style: TextStyle(
                          color: AppTheme.credWhite,
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeInAnimation(
                      delay: const Duration(milliseconds: 500),
                      child: const Text(
                        'Your money. Your move',
                        style: TextStyle(
                          color: AppTheme.credTextSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FadeInAnimation(
                      delay: const Duration(milliseconds: 800),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/onboarding');
                            },
                            style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.credOrangeSunshine,
            foregroundColor: AppTheme.credWhite,
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
