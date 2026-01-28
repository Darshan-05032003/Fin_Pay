import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/services/haptic_service.dart';
import 'package:fin_pay/services/user_service.dart';
import 'package:fin_pay/widgets/animations/cred_button_press.dart';
import 'package:fin_pay/widgets/animations/cred_card_reveal.dart';
import 'package:fin_pay/widgets/animations/cred_slide_in.dart';
import 'package:fin_pay/widgets/animations/fade_in_animation.dart';
import 'package:fin_pay/widgets/animations/pulse_animation.dart';
import 'package:fin_pay/widgets/animations/spring_animation.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.credPureBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.credTextPrimary),
          onPressed: () async {
            await HapticService.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CredSlideIn(
                delay: Duration(milliseconds: 100),
                child: Text(
                  'Welcome Back',
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
                  'Log in to securely access your account and manage your money anytime.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.credTextSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              CredSlideIn(
                delay: const Duration(milliseconds: 300),
                child: CredCardReveal(
                  perspective: 0.0008,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Focus(
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
                                controller: _emailController,
                                style: const TextStyle(color: AppTheme.credTextPrimary),
                                decoration: const InputDecoration(
                                  labelText: 'Email or phone',
                                  hintText: 'user@finpay.com',
                                  prefixIcon: Icon(Icons.email_outlined, color: AppTheme.credTextSecondary),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(20),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      CredSlideIn(
                        delay: const Duration(milliseconds: 350),
                        offset: const Offset(0, 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.credOrangeSunshine.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.credOrangeSunshine.withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.credOrangeSunshine, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Use: ${UserService.defaultEmail} / ${UserService.defaultPassword}',
                                  style: TextStyle(
                                    color: AppTheme.credTextSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CredSlideIn(
                delay: const Duration(milliseconds: 400),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 600),
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
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: AppTheme.credTextPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter password',
                              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.credTextSecondary),
                              suffixIcon: CredButtonPress(
                                onTap: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                  HapticService.selection();
                                },
                                child: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                    color: AppTheme.credTextSecondary,
                                  ),
                                  onPressed: null,
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeInAnimation(
                delay: const Duration(milliseconds: 500),
                child: Row(
                  children: [
                    const Text(
                      'Biometric Login',
                      style: TextStyle(color: AppTheme.credTextSecondary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await HapticService.lightImpact();
                        Navigator.pushNamed(context, '/forgot-password');
                      },
                      child: const Text(
                        'Forgot Password',
                        style: TextStyle(color: AppTheme.credOrangeSunshine),
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
                    if (_emailController.text.trim().isEmpty ||
                        _passwordController.text.trim().isEmpty) {
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
                    
                    // Only accept default credentials
                    final email = _emailController.text.trim();
                    final password = _passwordController.text.trim();
                    
                    final loginSuccess = await UserService.loginUser(email, password);
                    
                    if (!loginSuccess) {
                      await HapticService.error();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid email or password. Use: user@finpay.com / FinPay123'),
                          backgroundColor: AppTheme.credError,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    await HapticService.success();
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
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppTheme.credWhite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeInAnimation(
                delay: const Duration(milliseconds: 700),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: AppTheme.credMediumGray.withOpacity(0.3))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Or continue with',
                        style: TextStyle(color: AppTheme.credTextTertiary),
                      ),
                    ),
                    Expanded(child: Divider(color: AppTheme.credMediumGray.withOpacity(0.3))),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FadeInAnimation(
                delay: const Duration(milliseconds: 800),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialIcon(Icons.g_mobiledata, AppTheme.credError),
                    const SizedBox(width: 24),
                    _buildSocialIcon(Icons.facebook, AppTheme.credBlue),
                    const SizedBox(width: 24),
                    _buildSocialIcon(Icons.send, AppTheme.credOrangeSunshine),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              FadeInAnimation(
                delay: const Duration(milliseconds: 900),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(color: AppTheme.credTextSecondary),
                    ),
                    TextButton(
                      onPressed: () async {
                        await HapticService.lightImpact();
                        Navigator.pushNamed(context, '/create-account');
                      },
                      child: const Text(
                        'Create Account',
                        style: TextStyle(color: AppTheme.credOrangeSunshine),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return CredSlideIn(
      delay: const Duration(milliseconds: 850),
      offset: const Offset(0, 20),
      child: CredButtonPress(
        onTap: HapticService.selection,
        child: SpringAnimation(
          startOffset: const Offset(0, 10),
          child: PulseAnimation(
            minScale: 0.98,
            maxScale: 1.02,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.credSurfaceCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.credMediumGray.withOpacity(0.3),
                ),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
