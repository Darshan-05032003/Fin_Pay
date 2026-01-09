import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/haptic_service.dart';
import '../../widgets/animations/cred_slide_in.dart';
import '../../widgets/animations/cred_card_reveal.dart';
import '../../widgets/animations/cred_button_press.dart';
import '../../widgets/animations/spring_animation.dart';
import '../../widgets/animations/pulse_animation.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.credBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.credTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CredSlideIn(
                delay: const Duration(milliseconds: 100),
                offset: const Offset(0, 30),
                child: const Text(
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
              CredSlideIn(
                delay: const Duration(milliseconds: 200),
                offset: const Offset(0, 20),
                child: const Text(
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
                      duration: const Duration(seconds: 2),
                      minScale: 0.98,
                      maxScale: 1.02,
                      child: Container(
                        width: 200,
                        height: 200,
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
                offset: const Offset(0, 30),
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
                offset: const Offset(0, 30),
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
                offset: const Offset(0, 30),
                child: CredButtonPress(
                  onTap: () async {
                    await HapticService.lightImpact();
                    Navigator.pop(context);
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
        duration: const Duration(milliseconds: 500),
        perspective: 0.0006,
        child: Container(
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
              PulseAnimation(
                duration: const Duration(seconds: 2),
                minScale: 0.98,
                maxScale: 1.02,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppTheme.credPurpleGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.credPurple.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
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
