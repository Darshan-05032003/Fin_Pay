import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/theme.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/haptic_service.dart';
import '../../widgets/animations/skeleton_loader_full.dart';
import '../../widgets/animations/ripple_effect.dart';
import '../../widgets/animations/pull_to_refresh_custom.dart';
import '../../widgets/animations/cred_slide_in.dart';
import '../../widgets/animations/cred_card_reveal.dart';
import '../../widgets/animations/cred_button_press.dart';
import '../../widgets/animations/spring_animation.dart';
import '../../widgets/animations/pulse_animation.dart';
import '../../widgets/cred_bottom_navigation_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await UserService.getCurrentUser();
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.credPureBackground,
        body: const SkeletonList(itemCount: 5),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: AppTheme.credPureBackground,
        appBar: AppBar(
          title: const Text('Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('No user data found'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.credPureBackground,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await HapticService.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: CustomPullToRefresh(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              CredSlideIn(
                delay: const Duration(milliseconds: 100),
                offset: const Offset(0, 30),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 500),
                  perspective: 0.0008,
                  child: _buildProfileHeader(),
                ),
              ),
              CredSlideIn(
                delay: const Duration(milliseconds: 200),
                offset: const Offset(0, 30),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 600),
                  perspective: 0.0008,
                  child: _buildAccountInfo(context),
                ),
              ),
              CredSlideIn(
                delay: const Duration(milliseconds: 300),
                offset: const Offset(0, 30),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 700),
                  perspective: 0.0008,
                  child: _buildHelpSupport(context),
                ),
              ),
              CredSlideIn(
                delay: const Duration(milliseconds: 400),
                offset: const Offset(0, 30),
                child: CredCardReveal(
                  duration: const Duration(milliseconds: 800),
                  perspective: 0.0008,
                  child: _buildLogoutButton(context),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 3),
    );
  }

  Widget _buildProfileHeader() {
    final initials = _user!.fullName
        .split(' ')
        .map((n) => n[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.credSurfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.credMediumGray.withOpacity(0.2),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.credOrangeGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.credOrangeSunshine.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.credWhite,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user!.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.credTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _user!.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.credTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          RippleEffect(
            borderRadius: 20,
            onTap: () async {
              await HapticService.mediumImpact();
              _showEditDialog();
            },
            child: IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.credOrangeSunshine),
              onPressed: null,
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.credSurfaceCard,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: AppTheme.credTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'FinPay respects your privacy. We collect and use your information to provide and improve our services. Your data is stored locally on your device and is never shared with third parties without your consent.\n\n'
            'For the complete privacy policy, please visit our website or contact us at privacy@finpay.app.\n\n'
            'By using FinPay, you agree to our privacy practices as described in our Privacy Policy.',
            style: const TextStyle(
              color: AppTheme.credTextSecondary,
              fontSize: 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await HapticService.lightImpact();
              Navigator.pop(context);
            },
            child: const Text(
              'Close',
              style: TextStyle(color: AppTheme.credOrangeSunshine),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final nameController = TextEditingController(text: _user!.fullName);
    final emailController = TextEditingController(text: _user!.email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
              onPressed: () async {
                await HapticService.success();
                final updatedUser = _user!.copyWith(
                  fullName: nameController.text.trim(),
                  email: emailController.text.trim(),
                );
                await UserService.updateUser(updatedUser);
                Navigator.pop(context);
                _loadUserData();
              },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Info',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.credTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            icon: Icons.location_on,
            title: 'My Address',
            onTap: () {},
          ),
          _buildMenuItem(
            icon: Icons.credit_card,
            title: 'My Card',
            onTap: () {
              Navigator.pushNamed(context, '/cards');
            },
          ),
          _buildMenuItem(
            icon: Icons.history,
            title: 'Transaction History',
            onTap: () {
              Navigator.pushNamed(context, '/transactions');
            },
          ),
          _buildMenuItem(
            icon: Icons.security,
            title: 'Security',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSupport(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Help & Support',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.credTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'Help Center',
            onTap: () {},
          ),
          _buildMenuItem(
            icon: Icons.person_add,
            title: 'Invite Friends',
            onTap: () {},
          ),
          _buildMenuItem(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () async {
              // Open privacy policy - replace with your actual URL
              const privacyPolicyUrl = 'https://your-domain.com/privacy-policy';
              final uri = Uri.parse(privacyPolicyUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                // Show privacy policy in-app if URL fails
                _showPrivacyPolicyDialog(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return CredButtonPress(
      onTap: () async {
        await HapticService.selection();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.credSurfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.credMediumGray.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.credOrangeGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.credOrangeSunshine.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(icon, color: AppTheme.credWhite, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.credTextPrimary,
                ),
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
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: RippleEffect(
        borderRadius: 12,
        onTap: () async {
          await HapticService.mediumImpact();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () async {
                    await HapticService.lightImpact();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    await HapticService.heavyImpact();
                    await UserService.logout();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: AppTheme.credError),
                  ),
                ),
              ],
            ),
          );
        },
        child: CredButtonPress(
          onTap: () async {
            await HapticService.heavyImpact();
            await UserService.logout();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          },
          child: SpringAnimation(
            startOffset: const Offset(0, 20),
            endOffset: Offset.zero,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.credError,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.credError.withOpacity(0.4),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: const Center(
                child: Text(
                  'Logout',
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
