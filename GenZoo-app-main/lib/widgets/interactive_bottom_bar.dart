import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';

class InteractiveNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const InteractiveNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// A modern, floating, animated interactive bottom navigation bar with
/// spring physics, expanding gradient pills, and haptic feedback.
class InteractiveBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<InteractiveNavItem> items;

  const InteractiveBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.96)
                : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.4)
                    : AppColors.primary.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.withOpacity(0.15),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final isSelected = selectedIndex == index;
                final item = items[index];

                return _NavItemWidget(
                  isSelected: isSelected,
                  item: item,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onItemSelected(index);
                  },
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemWidget extends StatelessWidget {
  final bool isSelected;
  final InteractiveNavItem item;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.isSelected,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Bouncing & Scaling Icon
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: isSelected ? 0.8 : 1.0,
                end: isSelected ? 1.08 : 1.0,
              ),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    size: 22,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? Colors.grey.shade400
                            : const Color(0xFF64748B)),
                  ),
                );
              },
            ),

            // Animated Expandable Label for selected tab
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 240),
                          opacity: isSelected ? 1.0 : 0.0,
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
