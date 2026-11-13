import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';

class InteractiveNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge; // 0 = no badge

  const InteractiveNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  });
}

/// Floating bottom navigation bar.
///
/// A single gradient "pill" slides under the items and follows the
/// [PageController] while the user swipes between pages, so the bar always
/// mirrors the page position. Icons lift/scale and colours blend according to
/// how close each item is to the pill. Works in RTL and LTR.
class InteractiveBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<InteractiveNavItem> items;

  /// Optional controller whose `page` drives the sliding pill live.
  final PageController? controller;

  const InteractiveBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
    this.controller,
  });

  double _position() {
    final c = controller;
    if (c != null && c.hasClients && c.position.haveDimensions) {
      return (c.page ?? selectedIndex.toDouble())
          .clamp(0.0, (items.length - 1).toDouble());
    }
    return selectedIndex.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = items.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2023) : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.20 : 0.045),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : const Color(0xFFE7E9EC),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final itemW = (box.maxWidth - 12) / n;
              return Padding(
                padding: const EdgeInsets.all(6),
                child: AnimatedBuilder(
                  animation: controller ?? const AlwaysStoppedAnimation(0),
                  builder: (context, _) {
                    final pos = _position();
                    return Stack(
                      children: [
                        // Soft, single-color selection indicator.
                        Positioned.directional(
                          textDirection: Directionality.of(context),
                          start: pos * itemW,
                          top: 0,
                          bottom: 0,
                          width: itemW,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(isDark ? 0.24 : 0.11),
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(n, (i) {
                            final t =
                                (1 - (pos - i).abs()).clamp(0.0, 1.0).toDouble();
                            return SizedBox(
                              width: itemW,
                              child: _NavItem(
                                item: items[i],
                                t: t,
                                selected: i == selectedIndex,
                                isDark: isDark,
                                onTap: () {
                                  if (i != selectedIndex) {
                                    HapticFeedback.selectionClick();
                                  }
                                  onItemSelected(i);
                                },
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final InteractiveNavItem item;
  final double t; // 0 = far from pill, 1 = pill is on this item
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.t,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final idle = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final color = Color.lerp(idle, AppColors.primary, t)!;

    return InkResponse(
      onTap: onTap,
      radius: 34,
      containedInkWell: false,
      highlightShape: BoxShape.circle,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, -2.5 * t),
              child: Transform.scale(
                scale: 1 + 0.16 * t,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(t > 0.5 ? item.activeIcon : item.icon,
                        size: 24, color: color),
                    if (item.badge > 0)
                      Positioned.directional(
                        textDirection: Directionality.of(context),
                        end: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.badge > 9 ? '9+' : '${item.badge}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                color: color,
                fontWeight: t > 0.5 ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
