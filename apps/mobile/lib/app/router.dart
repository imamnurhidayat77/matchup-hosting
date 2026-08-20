import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';

import '../core/providers/auth_state_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/auth/recovery/forgot_password_screen.dart';
import '../features/auth/recovery/new_password_screen.dart';
import '../features/auth/recovery/otp_verification_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/discovery/presentation/discovery_screen.dart';
import '../features/discovery/presentation/activity_detail_screen.dart';
import '../features/discovery/presentation/filter_screen.dart';
import '../features/activities/presentation/create_activity_screen.dart';
import '../features/activities/presentation/my_activities_screen.dart';
import '../features/activities/presentation/joined_activities_screen.dart';
import '../features/activities/presentation/joined_activity_detail_screen.dart';
import '../features/activities/presentation/past_activity_review_screen.dart';
import '../features/activities/presentation/activity_participants_screen.dart';
import '../features/activities/presentation/activity_full_screen.dart';
import '../features/activities/presentation/check_in_screen.dart';
import '../features/activities/presentation/manage_activity_screen.dart';
import '../features/activities/presentation/match_screen.dart';
import '../features/preferences/presentation/get_to_know_1_screen.dart';
import '../features/preferences/presentation/get_to_know_2_screen.dart';
import '../features/preferences/presentation/preferences_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/player_profile_screen.dart';
import '../features/report/presentation/report_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/chat/presentation/messages_screen.dart';
import 'app_shell.dart';

// ─── Public routes (no auth required) ────────────────────────────────────────

const _publicPaths = {
  '/splash',
  '/onboarding',
  '/welcome',
  '/login',
  '/register',
  '/forgot-password',
  '/otp-verification',
  '/new-password',
};

// ─── AuthNotifier → Listenable bridge ────────────────────────────────────────
// GoRouter's refreshListenable rebuilds the router when auth state changes.

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}

// ─── Shared page transition ──────────────────────────────────────────────────
// Every pushed route (everything outside the ShellRoute below, and any
// GoRoute reached via context.push from inside it) gets the same slide+fade
// instead of the platform default. Tab switches inside ShellRoute stay
// instant — AppShell swaps `child` directly, it never goes through a
// GoRoute page transition (PRD Section 0.6 / Appendix D.1).
//
// Usage: replace `builder: (_, state) => Screen()` with
// `pageBuilder: (_, state) => appPage(state, const Screen())` on any route
// that should feel like a "push" rather than an instant swap.
CustomTransitionPage<void> appPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppDurations.base,
    reverseTransitionDuration: AppDurations.base,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

// ─── Builder ─────────────────────────────────────────────────────────────────

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final authStatus = ref.read(authStatusProvider);
      final location = state.matchedLocation;

      // While session check is in progress (AuthStatus.unknown), stay on
      // splash so the loading animation can finish.
      if (authStatus == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }

      final isPublic = _publicPaths.any((p) => location.startsWith(p));

      if (authStatus == AuthStatus.unauthenticated && !isPublic) {
        // Protected route hit without a session → gate to welcome.
        return '/welcome';
      }

      if (authStatus == AuthStatus.authenticated && isPublic) {
        // Already authenticated but navigating to auth screen → skip to app.
        if (location == '/splash') return null; // Let splash handle routing.
        return '/discovery';
      }

      return null; // No redirect needed.
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (_, state) {
          final email = state.extra as String? ?? '';
          return OtpVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/new-password',
        builder: (_, state) {
          final email = state.extra as String? ?? '';
          return NewPasswordScreen(email: email);
        },
      ),
      // Activity detail sits OUTSIDE the shell: the Figma design (node 43:201)
      // has no bottom navigation on this screen — its footer holds only the home
      // indicator. Note that joined-activity-detail (74:5) DOES keep the tab
      // bar, so only this route is hoisted out.
      //
      // Must be reached via context.push, never context.go — its back/dislike
      // buttons call Navigator.maybePop(), which needs a route to pop back to.
      // See test/widget/activity_detail_buttons_test.dart for the regression
      // this documents (PRD Appendix B.3).
      GoRoute(
        path: '/activity/:id',
        pageBuilder: (_, state) {
          final id = state.pathParameters['id'] ?? '1';
          return appPage(state, ActivityDetailScreen(activityId: id));
        },
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/discovery',
            builder: (_, _) => const DiscoveryScreen(),
          ),
          GoRoute(
            path: '/activities',
            builder: (_, _) => const MyActivitiesScreen(),
          ),
          GoRoute(
            path: '/create',
            builder: (_, _) => const CreateActivityScreen(),
          ),

          GoRoute(path: '/messages', builder: (_, _) => const MessagesScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/activity/:id/participants',
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return ActivityParticipantsScreen(activityId: id);
            },
          ),
          GoRoute(
            path: '/activity/:id/full',
            builder: (_, _) => const ActivityFullScreen(),
          ),
          GoRoute(
            path: '/manage-activity/:id',
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return ManageActivityScreen(activityId: id);
            },
          ),
          GoRoute(path: '/match/:id', builder: (_, _) => const MatchScreen()),
          GoRoute(
            path: '/joined-activities',
            builder: (_, _) => const JoinedActivitiesScreen(),
          ),
          GoRoute(
            path: '/joined-activity/:id',
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return JoinedActivityDetailScreen(activityId: id);
            },
          ),
          GoRoute(
            path: '/past-activity/:id/review',
            builder: (_, _) => const PastActivityReviewScreen(),
          ),
          GoRoute(
            path: '/get-to-know-1',
            builder: (_, _) => const GetToKnow1Screen(),
          ),
          GoRoute(
            path: '/get-to-know-2',
            builder: (_, _) => const GetToKnow2Screen(),
          ),
          GoRoute(
            path: '/preferences',
            builder: (_, _) => const PreferencesScreen(),
          ),
          GoRoute(path: '/filter', builder: (_, _) => const FilterScreen()),
          GoRoute(
            path: '/report/:type/:name',
            builder: (_, state) {
              final type = state.pathParameters['type'] ?? 'user';
              final name = state.pathParameters['name'] ?? 'Unknown';
              return ReportScreen(targetType: type, targetName: name);
            },
          ),
          GoRoute(
            path: '/chat/:title',
            builder: (_, state) {
              final title = state.pathParameters['title'] ?? 'Chat';
              return ChatScreen(activityTitle: title);
            },
          ),
          GoRoute(
            path: '/check-in/:id',
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return CheckInScreen(activityId: id);
            },
          ),
          GoRoute(path: '/calendar', builder: (_, _) => const CalendarScreen()),
          GoRoute(
            path: '/edit-profile',
            builder: (_, _) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/player-profile/:name',
            builder: (_, state) {
              final name = state.pathParameters['name'] ?? 'Player';
              return PlayerProfileScreen(playerName: name);
            },
          ),
        ],
      ),
    ],
  );
}
