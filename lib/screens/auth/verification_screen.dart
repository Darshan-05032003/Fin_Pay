import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/services/haptic_service.dart';
import 'package:fin_pay/services/user_service.dart';
import 'package:fin_pay/widgets/animations/cred_button_press.dart';
import 'package:fin_pay/widgets/animations/cred_card_reveal.dart';
import 'package:fin_pay/widgets/animations/cred_slide_in.dart';
import 'package:fin_pay/widgets/animations/pulse_animation.dart';
import 'package:fin_pay/widgets/animations/spring_animation.dart';
import 'package:flutter/material.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4,
    (index) => FocusNode(),
  );

  @override
  Widget build(BuildContext context) {
    final userData = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      body: Center(
        child: CredSlideIn(
          delay: const Duration(milliseconds: 100),
          child: CredCardReveal(
            duration: const Duration(milliseconds: 600),
            perspective: 0.0008,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.credSurfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.credMediumGray.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.credOrangeSunshine.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      CredSlideIn(
                        delay: const Duration(milliseconds: 200),
                        offset: const Offset(0, 20),
                        child: PulseAnimation(
                          minScale: 0.98,
                          maxScale: 1.02,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              gradient: AppTheme.credOrangeGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.credOrangeSunshine,
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: AppTheme.credWhite,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      CredButtonPress(
                        onTap: () async {
                          await HapticService.lightImpact();
                          Navigator.pop(context);
                        },
                        child: const Icon(Icons.close, color: AppTheme.credTextPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const CredSlideIn(
                    delay: Duration(milliseconds: 300),
                    offset: Offset(0, 20),
                    child: Text(
                      'Enter Verification Code!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.credTextPrimary,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const CredSlideIn(
                    delay: Duration(milliseconds: 400),
                    offset: Offset(0, 10),
                    child: Text(
                      'Enter the 4-digit verification code sent to your email address.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.credTextSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  CredSlideIn(
                    delay: const Duration(milliseconds: 500),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (index) {
                        return CredSlideIn(
                          delay: Duration(milliseconds: 600 + (index * 50)),
                          offset: const Offset(0, 20),
                          child: CredCardReveal(
                            duration: Duration(milliseconds: 400 + (index * 50)),
                            perspective: 0.0006,
                            child: SizedBox(
                              width: 60,
                              child: Focus(
                                child: Builder(
                                  builder: (context) {
                                    final hasFocus = Focus.of(context).hasFocus;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      decoration: BoxDecoration(
                                        color: AppTheme.credPureBackground,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: hasFocus
                                              ? AppTheme.credOrangeSunshine
                                              : AppTheme.credMediumGray.withOpacity(0.2),
                                          width: hasFocus ? 2 : 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _controllers[index],
                                        focusNode: _focusNodes[index],
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        maxLength: 1,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.credOrangeSunshine,
                                          letterSpacing: -1,
                                        ),
                                        decoration: const InputDecoration(
                                          counterText: '',
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.all(16),
                                        ),
                                        onChanged: (value) {
                                          HapticService.selection();
                                          if (value.isNotEmpty && index < 3) {
                                            _focusNodes[index + 1].requestFocus();
                                          } else if (value.isEmpty && index > 0) {
                                            _focusNodes[index - 1].requestFocus();
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CredSlideIn(
                    delay: const Duration(milliseconds: 800),
                    offset: const Offset(0, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Didn't get the code ",
                          style: TextStyle(color: AppTheme.credTextSecondary),
                        ),
                        CredButtonPress(
                          onTap: () async {
                            await HapticService.lightImpact();
                          },
                          child: const Text(
                            'Resend It',
                            style: TextStyle(
                              color: AppTheme.credOrangeSunshine,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CredSlideIn(
                    delay: const Duration(milliseconds: 900),
                    child: CredButtonPress(
                      onTap: () async {
                        // Verify all fields are filled
                        final code = _controllers.map((c) => c.text).join();
                        if (code.length != 4) {
                          await HapticService.error();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter the complete verification code'),
                              backgroundColor: AppTheme.credError,
                            ),
                          );
                          return;
                        }

                        await HapticService.mediumImpact();

                        // Only allow creating account with default credentials
                        if (userData != null) {
                          final email = userData['email']?.toString().trim().toLowerCase() ?? '';
                          final password = userData['password']?.toString() ?? '';
                          
                          // Check if using default credentials
                          if (email == UserService.defaultEmail.toLowerCase() && 
                              password == UserService.defaultPassword) {
                            final user = User(
                              id: 'default_user_001',
                              fullName: userData['fullName'] ?? UserService.defaultName,
                              email: UserService.defaultEmail,
                              password: UserService.defaultPassword,
                              balance: 56246.90, // Initial balance
                              createdAt: DateTime.now(),
                            );
                            await UserService.saveUser(user);
                            await HapticService.success();
                          } else {
                            // Show error - only default credentials allowed
                            await HapticService.error();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Only default credentials allowed. Use: user@finpay.com / FinPay123'),
                                backgroundColor: AppTheme.credError,
                                duration: Duration(seconds: 3),
                              ),
                            );
                            return;
                          }
                        }

                        Navigator.pushReplacementNamed(context, '/fingerprint-setup');
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
                              'Verify',
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

