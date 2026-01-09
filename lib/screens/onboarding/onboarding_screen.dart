import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../constants/theme.dart';
import '../../widgets/animations/cred_slide_in.dart';
import '../../widgets/animations/cred_card_reveal.dart';
import '../../widgets/animations/cred_button_press.dart';
import '../../widgets/animations/spring_animation.dart';
import '../../widgets/animations/pulse_animation.dart';
import '../../services/haptic_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Pay for everything easily and conveniently!',
      subtitle: 'Handle all your payments easily, anytime, from one secure app.',
      image: Icons.account_balance_wallet,
    ),
    OnboardingPage(
      title: 'Take control of your money like never before!',
      subtitle: 'Track expenses, make payments, and manage your money securely in one place.',
      image: Icons.pie_chart,
    ),
    OnboardingPage(
      title: 'Spend smarter every day with smarter tools in one app!',
      subtitle: 'Monitor spending, pay securely, and stay in control of your money in one place.',
      image: Icons.credit_card,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credBlack,
      body: SafeArea(
        child: Column(
          children: [
            CredSlideIn(
              delay: const Duration(milliseconds: 100),
              offset: const Offset(20, 0),
              child: Align(
                alignment: Alignment.topRight,
                child: CredButtonPress(
                  onTap: () async {
                    await HapticService.lightImpact();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppTheme.credWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildAnimatedPage(_pages[index], index);
                },
              ),
            ),
            CredSlideIn(
              delay: const Duration(milliseconds: 300),
              offset: const Offset(0, 20),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _pages.length,
                effect: const WormEffect(
                  activeDotColor: AppTheme.credPurple,
                  dotColor: AppTheme.credLightGray,
                  dotHeight: 10,
                  dotWidth: 10,
                  spacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 32),
            CredSlideIn(
              delay: const Duration(milliseconds: 400),
              offset: const Offset(0, 30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Row(
                  children: [
                    if (_currentPage < _pages.length - 1)
                      CredButtonPress(
                        onTap: () async {
                          await HapticService.lightImpact();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: AppTheme.credTextSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const Spacer(),
                    CredButtonPress(
                      onTap: () async {
                        await HapticService.mediumImpact();
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                          );
                        } else {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      child: SpringAnimation(
                        startOffset: const Offset(0, 20),
                        endOffset: Offset.zero,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.credPurpleGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.credPurple.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              color: AppTheme.credWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedPage(OnboardingPage page, int index) {
    final isCurrentPage = _currentPage == index;
    
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: isCurrentPage ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(30 * (1 - value), 0),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CredSlideIn(
                      delay: Duration(milliseconds: 200 + (index * 100)),
                      offset: const Offset(0, 30),
                      child: Text(
                        page.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.credTextPrimary,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CredSlideIn(
                      delay: Duration(milliseconds: 300 + (index * 100)),
                      offset: const Offset(0, 20),
                      child: Text(
                        page.subtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.credTextSecondary,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),
                    CredSlideIn(
                      delay: Duration(milliseconds: 400 + (index * 100)),
                      offset: const Offset(0, 40),
                      child: CredCardReveal(
                        duration: const Duration(milliseconds: 800),
                        perspective: 0.0008,
                        child: PulseAnimation(
                          duration: const Duration(seconds: 2),
                          minScale: 0.98,
                          maxScale: 1.02,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              gradient: AppTheme.credPurpleGradient,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.credPurple.withOpacity(0.4),
                                  blurRadius: 24,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Icon(
                              page.image,
                              size: 100,
                              color: AppTheme.credWhite,
                            ),
                          ),
                        ),
                      ),
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData image;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.image,
  });
}
