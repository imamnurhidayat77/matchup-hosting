import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matchup_mobile/core/providers/auth_state_provider.dart';
import 'package:matchup_mobile/core/providers/repository_providers.dart';

/// Regression test for "logout Benjamin → login Lisa still shows
/// Benjamin's My Games".
///
/// User-scoped repositories hold in-memory caches carrying the viewer's
/// identity (`RemoteActivityRepository._feedCache`,
/// `RemoteUserRepository._meCache`, …). They must be scoped to the
/// signed-in uid so an account switch discards the old instance (and its
/// cache) and every watcher refetches for the new user.
void main() {
  setUpAll(() async {
    // Repository providers read Env.useRemoteApi (dotenv.maybeGet),
    // which throws when dotenv was never loaded — same setup as
    // tour_first_run_test.dart.
    await dotenv.load(fileName: '.env.example');
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  void signInAs(ProviderContainer container, String userId) {
    container.read(authStateProvider.notifier).state = AuthState(
      status: AuthStatus.authenticated,
      userId: userId,
    );
  }

  group('session-scoped repositories', () {
    test('activity repository is recreated on account switch', () {
      final container = createContainer();

      final beforeLogin = container.read(activityRepositoryProvider);
      signInAs(container, 'benjamin');
      final benjamin = container.read(activityRepositoryProvider);
      expect(identical(beforeLogin, benjamin), isFalse);

      // Same uid, status flip only (e.g. suspended) — instance kept.
      container.read(authStateProvider.notifier).state = const AuthState(
        status: AuthStatus.suspended,
        userId: 'benjamin',
      );
      expect(
        identical(benjamin, container.read(activityRepositoryProvider)),
        isTrue,
      );

      // Logout → login as a different user — old instance (and its
      // feed cache) dropped.
      container.read(authStateProvider.notifier).state =
          AuthState.unauthenticated;
      signInAs(container, 'lisa');
      final lisa = container.read(activityRepositoryProvider);
      expect(identical(benjamin, lisa), isFalse);
    });

    test('user/chat/notification/swipes repositories follow the account', () {
      final container = createContainer();
      signInAs(container, 'benjamin');

      final userRepo = container.read(userRepositoryProvider);
      final chatRepo = container.read(chatRepositoryProvider);
      final notifRepo = container.read(notificationRepositoryProvider);
      final swipesRepo = container.read(swipesRepositoryProvider);

      container.read(authStateProvider.notifier).state =
          AuthState.unauthenticated;
      signInAs(container, 'lisa');

      expect(
        identical(userRepo, container.read(userRepositoryProvider)),
        isFalse,
      );
      expect(
        identical(chatRepo, container.read(chatRepositoryProvider)),
        isFalse,
      );
      expect(
        identical(notifRepo, container.read(notificationRepositoryProvider)),
        isFalse,
      );
      expect(
        identical(swipesRepo, container.read(swipesRepositoryProvider)),
        isFalse,
      );
    });
  });
}
