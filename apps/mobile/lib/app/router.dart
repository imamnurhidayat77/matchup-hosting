import 'package:go_router/go_router.dart';

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

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (_, _) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/new-password',
        builder: (_, _) => const NewPasswordScreen(),
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
          GoRoute(
            path: '/messages',
            builder: (_, _) => const MessagesScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/activity/:id',
            builder: (_, state) {
              final id = state.pathParameters['id'] ?? '1';
              return ActivityDetailScreen(activityId: id);
            },
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
          GoRoute(
            path: '/match/:id',
            builder: (_, _) => const MatchScreen(),
          ),
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
          GoRoute(
            path: '/filter',
            builder: (_, _) => const FilterScreen(),
          ),
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
          GoRoute(
            path: '/calendar',
            builder: (_, _) => const CalendarScreen(),
          ),
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