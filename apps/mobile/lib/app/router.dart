import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/discovery/presentation/discovery_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import 'app_shell.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/discovery',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/discovery',
            builder: (_, _) => const DiscoveryScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
    ],
  );
}