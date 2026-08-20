import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/home_indicator.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_NavTab>[
    _NavTab(
      label: 'Discover',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      route: '/discovery',
    ),
    _NavTab(
      label: 'Activities',
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      route: '/activities',
    ),
    _NavTab(
      label: 'Create',
      icon: Icons.add_box_outlined,
      activeIcon: Icons.add_box,
      // Single-scroll create screen. The multi-step wizard at
      // '/create-activity' is the older flow and is no longer the entry point.
      route: '/create',
    ),
    _NavTab(
      label: 'Chat',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      route: '/messages',
    ),
    _NavTab(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      route: '/profile',
    ),
  ];

  int _indexFor(String location) {
    if (location.startsWith('/discovery')) return 0;
    if (location.startsWith('/activities')) return 1;
    if (location.startsWith('/create-activity') ||
        location.startsWith('/create')) { return 2; }
    if (location.startsWith('/messages') || location.startsWith('/chat')) {
      return 3;
    }
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabBar(
            currentIndex: index,
            onTap: (i) => context.go(_tabs[i].route),
          ),
          const HomeIndicator(),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(AppShell._tabs.length, (i) {
          final tab = AppShell._tabs[i];
          final isSelected = i == currentIndex;
          return _NavItem(
            tab: tab,
            isSelected: isSelected,
            onTap: () => onTap(i),
          );
        }),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final _NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.primaryDarker
        : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: isSelected,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pill indicator behind the active icon — smooth on change.
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primarySoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(
                  isSelected ? tab.activeIcon : tab.icon,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: AppTypography.caption.copyWith(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  height: 1.0,
                  color: color,
                ),
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}
