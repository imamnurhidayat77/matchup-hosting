import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/providers/repository_providers.dart';
import 'features/notifications/services/presence_tracker.dart';
import 'features/notifications/services/push_notification_service.dart';
import 'firebase_options.dart';

/// Hive box for the create-activity form draft.
const String _draftBoxName = 'wizard_draft';

/// Top-level background message handler. Must be a top-level function
/// annotated with `@pragma('vm:entry-point')` so the engine keeps it
/// alive when the app is backgrounded. Registered before `runApp` so
/// it's wired up before any message can arrive.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Background messages don't need to do anything special here — the
  // OS displays the notification. The hook exists so the background
  // isolate can be configured (e.g. to load SharedPreferences).
  if (kDebugMode) {
    debugPrint(
      '[FCM] Background message: ${message.notification?.title ?? message.data}',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await Env.load();

  await Hive.initFlutter();
  await Hive.openBox(_draftBoxName);

  // Initialise Firebase with the generated options (project
  // matchup-cs734). Wrapped in try/catch so a failure here doesn't
  // brick the app — chat falls back to HTTP polling and FCM is a
  // no-op until Firebase is healthy.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[main] Firebase.initializeApp() failed: $e\n$st');
    }
  }

  // Register the background handler before runApp so the engine keeps
  // the function reference alive in the background isolate.
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (e) {
    if (kDebugMode) debugPrint('[main] onBackgroundMessage register failed: $e');
  }

  final container = ProviderContainer();

  // Initialise push notifications after the provider container is built
  // so the device repository can be resolved. This is fire-and-forget;
  // FCM failures must never block the splash screen.
  unawaited(
    PushNotificationService.instance.initialize(
      deviceRepository: container.read(deviceRepositoryProvider),
    ),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      // PresenceTracker observes app-lifecycle events (resumed → online,
      // paused/detached → offline) and forwards them to the backend's
      // presence API. Wrapping MatchUpApp here is enough — no screen
      // below needs to wire up WidgetsBindingObserver on its own.
      child: const PresenceTracker(child: MatchUpApp()),
    ),
  );
}

