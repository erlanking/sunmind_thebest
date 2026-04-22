import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback? onTap;

  const AppBottomNavBar({super.key, required this.currentIndex, this.onTap});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/analytics');
        break;
      case 2:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0F14) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF262A32) : const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Главная',
                isSelected: currentIndex == 0,
                onTap: () => _onItemTapped(context, 0),
              ),
              _NavItem(
                icon: Icons.analytics_rounded,
                label: 'Аналитика',
                isSelected: currentIndex == 1,
                onTap: () => _onItemTapped(context, 1),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Профиль',
                isSelected: currentIndex == 2,
                onTap: () => _onItemTapped(context, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFFF6C343);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleColor = isDark ? Colors.white54 : const Color(0xFF6C7380);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isSelected ? 1.1 : 1.0,
              child: Icon(
                icon,
                color: isSelected ? accentColor : idleColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accentColor : idleColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
