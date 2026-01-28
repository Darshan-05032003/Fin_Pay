import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/services/haptic_service.dart';
import 'package:fin_pay/widgets/animations/cred_button_press.dart';
import 'package:fin_pay/widgets/animations/cred_card_reveal.dart';
import 'package:fin_pay/widgets/animations/cred_slide_in.dart';
import 'package:fin_pay/widgets/animations/pulse_animation.dart';
import 'package:fin_pay/widgets/animations/spring_animation.dart';
import 'package:flutter/material.dart';

class FingerprintSetupScreen extends StatelessWidget {
  const FingerprintSetupScreen({super.key});

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
              const SizedBox(height: 32),
              const CredSlideIn(
                delay: Duration(milliseconds: 100),
                child: Text(
                  'Set Up Your Fingerprint',
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
                  'Add your fingerprint to protect your account and keep your transactions safe.',
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
                      maxScale: 1.05,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: AppTheme.credOrangeGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.credOrangeSunshine.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          size: 120,
                          color: AppTheme.credWhite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const CredSlideIn(
                delay: Duration(milliseconds: 400),
                offset: Offset(0, 20),
                child: Text(
                  'Place your finger on the fingerprint scanner to quickly and securely access your account.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.credTextSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              CredSlideIn(
                delay: const Duration(milliseconds: 500),
                child: CredButtonPress(
                  onTap: () async {
                    await HapticService.mediumImpact();
                    Navigator.pushReplacementNamed(context, '/home');
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
                          'Set Up Fingerprint',
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

