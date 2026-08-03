import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = <_NavTab>[
    _NavTab(label: 'Discover', icon: Icons.explore_outlined, route: '/discovery'),
    _NavTab(label: 'Profile', icon: Icons.person_outline, route: '/profile'),
    _NavTab(
        label: 'Notifications',
        icon: Icons.notifications_outlined,
        route: '/notifications'),
  ];

  int _indexFor(String location) {
    final i = _tabs.indexWhere((t) => location.startsWith(t.route));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].route),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}

class _NavTab {
  const _NavTab({required this.label, required this.icon, required this.route});

  final String label;
  final IconData icon;
  final String route;
}