import 'package:fin_pay/constants/theme.dart';
import 'package:fin_pay/core/di/injection_container.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:flutter/material.dart';

/// CRED-style bottom navigation bar with "Light Switch" effect
/// Selected items "light up" with bright colors against dark background
class CredBottomNavigationBar extends StatelessWidget {
  const CredBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });
  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.credSurfaceCard,
        border: Border(
          top: BorderSide(
            color: AppTheme.credMediumGray.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor:
            AppTheme.credOrangeSunshine, // "Lights up" with orange
        unselectedItemColor:
            AppTheme.credTextTertiary, // Dim grey when not selected
        selectedFontSize: 12,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
        onTap: (index) async {
          await sl<HapticService>().selection();
          onTap(index);
        },
        items: [
          _buildNavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isSelected: currentIndex == 0,
          ),
          _buildNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'Stats',
            isSelected: currentIndex == 1,
          ),
          _buildNavItem(
            icon: Icons.credit_card_rounded,
            label: 'Cards',
            isSelected: currentIndex == 2,
          ),
          _buildNavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            isSelected: currentIndex == 3,
          ),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.credOrangeSunshine.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 24),
      ),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.credOrangeSunshine.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 24),
      ),
      label: label,
    );
  }
}
