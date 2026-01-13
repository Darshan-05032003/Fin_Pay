import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../services/user_service.dart';
import '../../services/haptic_service.dart';
import '../../widgets/animations/fade_in_animation.dart';
import '../../widgets/animations/cred_slide_in.dart';
import '../../widgets/animations/cred_button_press.dart';
import '../../widgets/animations/cred_card_reveal.dart';
import '../../widgets/animations/spring_animation.dart';
import '../../widgets/animations/ripple_effect.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.credPureBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.credTextPrimary),
          onPressed: () async {
            await HapticService.lightImpact();
            Navigator.pop(context);
          },
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
                  'Create An Account',
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
                  'Create an account to securely manage your money and access essential banking features.',
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
                offset: const Offset(0, 30),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 500),
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
                            controller: _nameController,
                            style: const TextStyle(color: AppTheme.credTextPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'Full name',
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
              const SizedBox(height: 20),
              CredSlideIn(
                delay: const Duration(milliseconds: 400),
                offset: const Offset(0, 30),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 600),
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
                        delay: const Duration(milliseconds: 450),
                        offset: const Offset(0, 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.credOrangeSunshine.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.credOrangeSunshine.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.credOrangeSunshine, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Only default credentials work: ${UserService.defaultEmail} / ${UserService.defaultPassword}',
                                  style: const TextStyle(
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
                delay: const Duration(milliseconds: 500),
                offset: const Offset(0, 30),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 700),
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
                delay: const Duration(milliseconds: 600),
                child: const Text(
                  "By starting my application, I agree to FinPay's Terms of service and Privacy Policy.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.credTextTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              CredSlideIn(
                delay: const Duration(milliseconds: 600),
                offset: const Offset(0, 30),
                child: CredButtonPress(
                  onTap: () async {
                    if (_nameController.text.trim().isEmpty ||
                        _emailController.text.trim().isEmpty ||
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
                    // Save user data temporarily to pass to verification
                    final userData = {
                      'fullName': _nameController.text.trim(),
                      'email': _emailController.text.trim(),
                      'password': _passwordController.text.trim(),
                    };

                    Navigator.pushNamed(
                      context,
                      '/verification',
                      arguments: userData,
                    );
                  },
                  child: SpringAnimation(
                    startOffset: const Offset(0, 20),
                    endOffset: Offset.zero,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.credOrangeGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.credOrangeSunshine.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: const Center(
                        child: Text(
                          'Create Account',
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: AppTheme.credMediumGray.withOpacity(0.3))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Or continue with',
                      style: TextStyle(color: AppTheme.credTextTertiary),
                    ),
                  ),
                  Expanded(child: Divider(color: AppTheme.credMediumGray.withOpacity(0.3))),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialIcon(Icons.g_mobiledata, Colors.red),
                  const SizedBox(width: 24),
                  _buildSocialIcon(Icons.facebook, Colors.blue),
                  const SizedBox(width: 24),
                  _buildSocialIcon(Icons.send, Colors.lightBlue),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: AppTheme.credTextSecondary),
                  ),
                  TextButton(
                    onPressed: () async {
                      await HapticService.lightImpact();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(color: AppTheme.credOrangeSunshine),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: RippleEffect(
            borderRadius: 28,
            onTap: () => HapticService.selection(),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.credSurfaceCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.credMediumGray.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

