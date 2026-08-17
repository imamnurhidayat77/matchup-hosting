import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/widgets/home_indicator.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_NavTab>[
    _NavTab(
      label: 'Discover',
      iconAsset: 'assets/images/discovery/icons/compass.svg',
      route: '/discovery',
    ),
    _NavTab(
      label: 'Activities',
      iconAsset: 'assets/images/discovery/icons/calendar.svg',
      route: '/activities',
    ),
    _NavTab(
      label: 'Create',
      iconAsset: 'assets/images/discovery/icons/plus_square.svg',
      route: '/create',
    ),
    _NavTab(
      label: 'Chat',
      iconAsset: 'assets/images/discovery/icons/message_square.svg',
      route: '/messages',
    ),
    _NavTab(
      label: 'Profile',
      iconAsset: 'assets/images/discovery/icons/user.svg',
      route: '/profile',
    ),
  ];

  int _indexFor(String location) {
    if (location.startsWith('/discovery')) return 0;
    if (location.startsWith('/activities')) return 1;
    if (location.startsWith('/create')) return 2;
    if (location.startsWith('/messages') || location.startsWith('/chat')) return 3;
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
          _TabBar(currentIndex: index, onTap: (i) => context.go(_tabs[i].route)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    final color = isSelected ? AppColors.primaryDarker : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: isSelected,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: SvgPicture.asset(
                  tab.iconAsset,
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  color: color,
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
    required this.iconAsset,
    required this.route,
  });

  final String label;
  final String iconAsset;
  final String route;
}
