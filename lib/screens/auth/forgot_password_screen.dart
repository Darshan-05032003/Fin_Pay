import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/services/haptic_service.dart';
import 'package:fin_pay/widgets/animations/cred_button_press.dart';
import 'package:fin_pay/widgets/animations/cred_card_reveal.dart';
import 'package:fin_pay/widgets/animations/cred_slide_in.dart';
import 'package:fin_pay/widgets/animations/pulse_animation.dart';
import 'package:fin_pay/widgets/animations/spring_animation.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.credPureBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.credTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CredSlideIn(
                delay: Duration(milliseconds: 100),
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.credTextPrimary,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const CredSlideIn(
                delay: Duration(milliseconds: 200),
                offset: Offset(0, 20),
                child: Text(
                  'Choose a recovery method to reset your password.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.credTextSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              CredSlideIn(
                delay: const Duration(milliseconds: 300),
                offset: const Offset(0, 40),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 800),
                  perspective: 0.0008,
                  child: Center(
                    child: PulseAnimation(
                      minScale: 0.98,
                      maxScale: 1.02,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: AppTheme.credOrangeGradient,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.credOrangeSunshine.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.security,
                          size: 100,
                          color: AppTheme.credWhite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              CredSlideIn(
                delay: const Duration(milliseconds: 400),
                child: _buildRecoveryOption(
                  icon: Icons.fingerprint,
                  title: 'Biometric Scan',
                  description:
                      'Use your fingerprint to quickly and securely reset your password.',
                  onTap: () async {
                    await HapticService.mediumImpact();
                  },
                ),
              ),
              const SizedBox(height: 16),
              CredSlideIn(
                delay: const Duration(milliseconds: 500),
                child: _buildRecoveryOption(
                  icon: Icons.chat_bubble_outline,
                  title: 'Chat with FinPay Agent',
                  description:
                      'Get help from our support team to reset your password.',
                  onTap: () async {
                    await HapticService.mediumImpact();
                  },
                ),
              ),
              const SizedBox(height: 32),
              CredSlideIn(
                delay: const Duration(milliseconds: 600),
                child: CredButtonPress(
                  onTap: () async {
                    await HapticService.lightImpact();
                    Navigator.pop(context);
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
                          'Continue',
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
      ),
    );
  }

  Widget _buildRecoveryOption({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return CredButtonPress(
      onTap: onTap,
      child: CredCardReveal(
        perspective: 0.0006,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.credSurfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.credMediumGray.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              PulseAnimation(
                minScale: 0.98,
                maxScale: 1.02,
                child: Container(
                  width: 56,
                  height: 56,
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
                  child: Icon(icon, color: AppTheme.credWhite, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.credTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.credTextSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.credTextSecondary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
