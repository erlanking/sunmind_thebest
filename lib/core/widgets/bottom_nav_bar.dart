import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// Sunrise gradient constants
const _kA1 = Color(0xFFFFD54F);
const _kA2 = Color(0xFFFF9F43);
const _kA3 = Color(0xFFFF6B35);
const _kGlow = Color(0x66FFB440);

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AppBottomNavBar({super.key, required this.currentIndex, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(12, 0, 12, (bottomPad > 0 ? bottomPad : 14)),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xD917171B) : const Color(0xEAFFFFFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF26262D) : const Color(0xFFE8E5DE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: [
            _NavPill(
              icon: Icons.home_rounded,
              label: 'nav.home'.tr(),
              isSelected: currentIndex == 0,
              isDark: isDark,
              onTap: () => onTap?.call(0),
            ),
            _NavPill(
              icon: Icons.battery_charging_full_rounded,
              label: 'nav.battery'.tr(),
              isSelected: currentIndex == 1,
              isDark: isDark,
              onTap: () => onTap?.call(1),
            ),
            _NavPill(
              icon: Icons.bar_chart_rounded,
              label: 'nav.analytics'.tr(),
              isSelected: currentIndex == 2,
              isDark: isDark,
              onTap: () => onTap?.call(2),
            ),
            _NavPill(
              icon: Icons.person_rounded,
              label: 'nav.profile'.tr(),
              isSelected: currentIndex == 3,
              isDark: isDark,
              onTap: () => onTap?.call(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final idleColor = isDark
        ? const Color(0xFF6E6E75)
        : const Color(0xFF8E8E93);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 14 : 0,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [_kA1, _kA2, _kA3],
                    stops: [0.0, 0.55, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(22),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _kGlow,
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF1A0F00) : idleColor,
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF1A0F00),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
