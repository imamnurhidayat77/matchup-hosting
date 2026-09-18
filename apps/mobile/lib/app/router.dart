import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/route_store.dart';
import '../core/theme/app_spacing.dart';

import '../core/providers/auth_state_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/auth/recovery/forgot_password_screen.dart';
import '../features/auth/recovery/reset_link_sent_screen.dart';
import '../features/appeals/presentation/suspended_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/discovery/presentation/discovery_screen.dart';
import '../features/discovery/presentation/activity_detail_screen.dart';
import '../features/discovery/presentation/filter_screen.dart';
import '../features/activities/presentation/create_activity_screen.dart';
import '../features/activities/presentation/my_activities_screen.dart';
import '../features/activities/presentation/joined_activity_detail_screen.dart';
import '../features/activities/presentation/past_activity_review_screen.dart';
import '../features/activities/presentation/pending_request_detail_screen.dart';
import '../features/activities/presentation/activity_participants_screen.dart';
import '../features/activities/presentation/activity_full_screen.dart';
import '../features/activities/presentation/check_in_screen.dart';
import '../features/activities/presentation/edit_activity_screen.dart';
import '../features/activities/presentation/manage_activity_screen.dart';
import '../features/activities/presentation/join_request_sent_screen.dart';
import '../features/activities/presentation/match_screen.dart';
import '../features/preferences/presentation/get_to_know_1_screen.dart';
import '../features/preferences/presentation/get_to_know_2_screen.dart';
import '../features/preferences/presentation/get_to_know_3_screen.dart';
import '../features/preferences/presentation/preferences_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/notifications/presentation/notification_settings_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/player_profile_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/chat/presentation/photo_moments_screen.dart';
import '../features/chat/presentation/dm_screen.dart';
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
  '/reset-link-sent',
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
// Every route reached via context.push() — whether it lives outside the
// ShellRoute below or inside it — gets the same slide+fade instead of the
// platform default (PRD Section 0.6 / Appendix D.1). Routes reached only via
// context.go() (the five tab roots, plus the swipe-to-match reveal) keep
// plain `builder:` — go() replaces the shell's matched child in place, it
// never plays a page transition regardless of what the route's builder
// returns, so giving those a pageBuilder would be dead code.
//
// Usage: replace `builder: (_, state) => Screen()` with
// `pageBuilder: (_, state) => appPage(state, const Screen())` on any route
// that should feel like a "push" rather than an instant swap.
CustomTransitionPage<void> appPage(
  GoRouterState state,
  Widget child, {
  LocalKey? key,
}) {
  return CustomTransitionPage<void>(
    key: key ?? state.pageKey,
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

/// Root navigator key — lets notification taps and other app-level
/// triggers navigate without a widget context (see `_PushRouter` in
/// `app.dart`, which resolves its context from this key).
final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Page not found'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/discovery'),
                child: const Text('Back to Discovery'),
              ),
            ],
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      // Persist allow-listed locations only (tab roots + /activity*
      // detail). RouteStore.save enforces the allow-list; splash,
      // suspended, auth, and GTK routes are never stored.
      RouteStore.instance.save(state.matchedLocation);

      final authStatus = ref.read(authStatusProvider);
      final location = state.matchedLocation;

      // While session check is in progress (AuthStatus.unknown), stay on
      // splash so the loading animation can finish.
      if (authStatus == AuthStatus.unknown) {
        return location == '/splash' ? null : '/splash';
      }

      // Suspended accounts are locked to the interstitial: no tabs, no
      // auth screens, no deep content. Tokens are kept (appeals need
      // them); sign-out inside the interstitial flips to unauthenticated.
      if (authStatus == AuthStatus.suspended) {
        return location == '/suspended' ? null : '/suspended';
      }

      final isPublic = _publicPaths.any(
        (p) => location == p || location.startsWith('$p/'),
      );

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
      // Suspended interstitial — outside the shell (no tab bar), reached
      // only via the auth redirect above, never via context.go().
      GoRoute(
        path: '/suspended',
        pageBuilder: (_, state) => appPage(state, const SuspendedScreen()),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-link-sent',
        pageBuilder: (_, state) {
          final email =
              state.uri.queryParameters['email'] ??
              (state.extra is String ? state.extra as String : '');
          return appPage(
            state,
            ResetLinkSentScreen(email: email),
            key: ValueKey('reset-link-sent-$email'),
          );
        },
      ),
      // Post-signup preference flow sits OUTSIDE the shell: the user hasn't
      // landed in the app proper yet, so showing the tab bar here would let
      // them skip the flow by tapping a tab.
      GoRoute(
        path: '/get-to-know-1',
        pageBuilder: (_, state) => appPage(state, const GetToKnow1Screen()),
      ),
      GoRoute(
        path: '/get-to-know-2',
        pageBuilder: (_, state) => appPage(state, const GetToKnow2Screen()),
      ),
      GoRoute(
        path: '/get-to-know-3',
        pageBuilder: (_, state) => appPage(state, const GetToKnow3Screen()),
      ),
      // Activity detail sits OUTSIDE the shell: the Figma design (node 43:201)
      // has no bottom navigation on this screen — its footer holds only the home
      // indicator. Note that joined-activity-detail (74:5) DOES keep the tab
      // bar, so only this route is hoisted out.
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // Activity detail lives INSIDE the shell (not top-level):
          // pushing a shell-child route (host profile, full view,
          // participants…) from a top-level screen re-adds the shell
          // page with an identical key and red-screens
          // ('!keyReservation.contains(key)'). Intra-shell pushes never
          // duplicate. The tab bar stays hidden on exact detail
          // locations (see AppShell) so the full-screen look is kept.
          //
          // Must be reached via context.push, never context.go — its back/dislike
          // buttons call Navigator.maybePop(), which needs a route to pop back to.
          // See test/widget/activity_detail_buttons_test.dart for the regression
          // this documents (PRD Appendix B.3).
          GoRoute(
            path: '/activity/:id',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return appPage(
                state,
                ActivityDetailScreen(activityId: id),
                key: ValueKey('activity-$id'),
              );
            },
          ),
          // Tab roots — reached only via context.go() from AppShell's tab
          // bar (or the auth/flow redirects above). go() replaces the
          // shell's matched child in place rather than pushing a page, so
          // these never animate through appPage regardless of what their
          // builder returns; kept as plain `builder:` for clarity.
          GoRoute(
            path: '/discovery',
            builder: (_, _) => const DiscoveryScreen(),
          ),
          GoRoute(
            path: '/activities',
            builder: (_, _) => const MyActivitiesScreen(),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),

          // Also tab roots, but ALSO reached via context.push() from other
          // screens (My Activities' empty-state CTA → /create;
          // joined-activity-detail's "Message host" → /messages). A
          // pushed route always animates through its own pageBuilder
          // regardless of go_router's instant same-shell swap for go(), so
          // these need appPage for the pushed case without affecting the
          // tab-bar's go()-based instant switch.
          GoRoute(
            path: '/create',
            pageBuilder: (_, state) =>
                appPage(state, const CreateActivityScreen()),
          ),
          GoRoute(
            path: '/messages',
            pageBuilder: (_, state) => appPage(state, const MessagesScreen()),
          ),

          // Match reveal — reached only via context.go() from Discovery
          // after a swipe-right match (PRD: no "back" to the swipe deck
          // once matched), so it intentionally has no push transition.
          GoRoute(
            path: '/match/:id',
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return MatchScreen(activityId: id);
            },
          ),
          GoRoute(
            path: '/request-sent/:id',
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return JoinRequestSentScreen(activityId: id);
            },
          ),

          // Everything below is reached exclusively via context.push() —
          // each gets the shared appPage slide+fade so every push feels
          // consistent (PRD Section 0.6 / Appendix D.1).
          GoRoute(
            path: '/notifications',
            pageBuilder: (_, state) =>
                appPage(state, const NotificationsScreen()),
          ),
          GoRoute(
            path: '/notification-settings',
            pageBuilder: (_, state) =>
                appPage(state, const NotificationSettingsScreen()),
          ),
          GoRoute(
            path: '/activity/:id/participants',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return appPage(
                state,
                ActivityParticipantsScreen(activityId: id),
                key: ValueKey('activity-participants-$id'),
              );
            },
          ),
          GoRoute(
            path: '/activity/:id/full',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return appPage(
                state,
                ActivityFullScreen(activityId: id),
                key: ValueKey('activity-full-$id'),
              );
            },
          ),
          GoRoute(
            path: '/manage-activity/:id',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return appPage(
                state,
                ManageActivityScreen(activityId: id),
                key: ValueKey('manage-activity-$id'),
              );
            },
          ),
          // '/joined-activities' removed (PRD Section 3 / Appendix E.2):
          // JoinedActivitiesScreen duplicated My Activities and nothing in
          // the app ever navigated to it — confirmed via a full-repo grep
          // for '/joined-activities' before deleting the screen + route.
          GoRoute(
            path: '/joined-activity/:id',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return appPage(
                state,
                JoinedActivityDetailScreen(activityId: id),
                key: ValueKey('joined-activity-$id'),
              );
            },
          ),
          GoRoute(
            path: '/past-activity/:id/review',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return appPage(
                state,
                PastActivityReviewScreen(activityId: id),
                key: ValueKey('past-activity-review-$id'),
              );
            },
          ),
          GoRoute(
            path: '/pending-request/:id',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return appPage(
                state,
                PendingRequestDetailScreen(activityId: id),
                key: ValueKey('pending-request-$id'),
              );
            },
          ),
          GoRoute(
            path: '/preferences',
            pageBuilder: (_, state) =>
                appPage(state, const PreferencesScreen()),
          ),
          GoRoute(
            path: '/filter',
            pageBuilder: (_, state) => appPage(state, const FilterScreen()),
          ),
          // /report/:type/:name removed — replaced by `ReportActivitySheet`
          // shown via showModalBottomSheet. The route form crashed with
          // '!keyReservation.contains(key)' on double-tap/race; modal sheets
          // sidestep that because they live in an Overlay, not a Page.
          GoRoute(
            // Uses the *activity id* (not title) so backend calls —
            // `/api/chat/{id}/messages`, `/api/typing/{id}/:uid`, the
            // RTDB `activityChats/{id}` ref — all hit real rows.
            // The screen fetches the activity to display the title.
            path: '/chat/:id',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '';
              return appPage(
                state,
                ChatScreen(activityId: id),
                key: ValueKey('chat-$id'),
              );
            },
          ),
          GoRoute(
            // Album of every photo shared in the activity's group chat.
            path: '/chat/:id/moments',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '';
              return appPage(
                state,
                PhotoMomentsScreen(activityId: id),
                key: ValueKey('chat-moments-$id'),
              );
            },
          ),
          GoRoute(
            // 1-on-1 thread with another user. Peer display name rides
            // along as route `extra` (falls back to a generic label on
            // cold-start push taps where no name is available).
            path: '/dm/:uid',
            pageBuilder: (_, state) {
              final uid = state.pathParameters['uid'] ?? '';
              final name = state.extra is String ? state.extra as String : null;
              return appPage(
                state,
                DmScreen(otherUid: uid, peerName: name),
                key: ValueKey('dm-$uid'),
              );
            },
          ),
          GoRoute(
            path: '/check-in/:id',
            pageBuilder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return appPage(
                state,
                CheckInScreen(activityId: id),
                key: ValueKey('check-in-$id'),
              );
            },
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (_, state) => appPage(state, const CalendarScreen()),
          ),
          GoRoute(
            path: '/edit-profile',
            pageBuilder: (_, state) =>
                appPage(state, const EditProfileScreen()),
          ),
          GoRoute(
            path: '/player-profile/:name',
            pageBuilder: (_, state) {
              final name = state.pathParameters['name'] ?? 'Player';
              return appPage(
                state,
                PlayerProfileScreen(playerName: name),
                key: ValueKey('player-profile-$name'),
              );
            },
          ),
          GoRoute(
            // Same screen by auth uid — exact and URL-safe. Preferred
            // when the uid is known (e.g. personal-chat settings).
            path: '/player-profile/uid/:uid',
            pageBuilder: (_, state) {
              final uid = state.pathParameters['uid'] ?? '';
              return appPage(
                state,
                PlayerProfileScreen.byUid(userId: uid),
                key: ValueKey('player-profile-uid-$uid'),
              );
            },
          ),
        ],
      ),
    ],
  );
}
