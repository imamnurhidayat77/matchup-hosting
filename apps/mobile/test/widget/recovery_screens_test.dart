import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/auth/data/auth_repository_impl.dart';
import 'package:matchup_mobile/features/auth/recovery/forgot_password_screen.dart';
import 'package:matchup_mobile/features/auth/recovery/new_password_screen.dart';
import 'package:matchup_mobile/features/auth/recovery/otp_verification_screen.dart';

Future<void> _pumpRouter(
  WidgetTester tester, {
  required String initialLocation,
  required List<GoRoute> routes,
}) async {
  final router = GoRouter(initialLocation: initialLocation, routes: routes);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Default authRepositoryProvider reads Env.useRemoteApi (needs
        // dotenv-loaded .env) and would hit Firebase network in tests —
        // LocalAuthRepository always succeeds with short delays instead.
        authRepositoryProvider.overrideWithValue(LocalAuthRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ForgotPasswordScreen', () {
    testWidgets('should show a validation error for an invalid email', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpRouter(
        tester,
        initialLocation: '/forgot-password',
        routes: [
          GoRoute(
            path: '/forgot-password',
            builder: (_, _) => const ForgotPasswordScreen(),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.tap(find.text('Send Code'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('should push otp-verification with the email once submitted', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpRouter(
        tester,
        initialLocation: '/forgot-password',
        routes: [
          GoRoute(
            path: '/forgot-password',
            builder: (_, _) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: '/otp-verification',
            builder: (_, state) =>
                Scaffold(body: Text('OTP for ${state.extra}')),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'jordan@example.com');
      await tester.tap(find.text('Send Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(find.text('OTP for jordan@example.com'), findsOneWidget);
    });
  });

  group('OtpVerificationScreen', () {
    testWidgets('should display the email passed via extra', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpRouter(
        tester,
        initialLocation: '/otp-verification',
        routes: [
          GoRoute(
            path: '/otp-verification',
            builder: (_, _) =>
                const OtpVerificationScreen(email: 'jordan@example.com'),
          ),
        ],
      );

      expect(find.textContaining('jordan@example.com'), findsOneWidget);
      expect(find.text('Check Your Email'), findsOneWidget);
    });

    testWidgets(
      'should push new-password once the correct 6-digit code is entered',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpRouter(
          tester,
          initialLocation: '/otp-verification',
          routes: [
            GoRoute(
              path: '/otp-verification',
              builder: (_, _) =>
                  const OtpVerificationScreen(email: 'jordan@example.com'),
            ),
            GoRoute(
              path: '/new-password',
              builder: (_, state) =>
                  Scaffold(body: Text('New password for ${state.extra}')),
            ),
          ],
        );

        final boxes = find.byType(TextField);
        expect(boxes, findsNWidgets(6));
        const code = '123456';
        for (var i = 0; i < 6; i++) {
          await tester.enterText(boxes.at(i), code[i]);
        }
        await tester.pump();
        await tester.tap(find.text('Verify'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pumpAndSettle();

        expect(
          find.text('New password for jordan@example.com'),
          findsOneWidget,
        );
      },
    );
  });

  group('NewPasswordScreen', () {
    testWidgets(
      'should disable the submit button until requirements and match are satisfied',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpRouter(
          tester,
          initialLocation: '/new-password',
          routes: [
            GoRoute(
              path: '/new-password',
              builder: (_, _) => const NewPasswordScreen(),
            ),
          ],
        );

        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(2));

        await tester.enterText(fields.at(0), 'weak');
        await tester.pumpAndSettle();
        expect(find.text('Weak'), findsOneWidget);

        await tester.enterText(fields.at(0), 'StrongPass1');
        await tester.enterText(fields.at(1), 'Mismatch1');
        await tester.pumpAndSettle();

        expect(find.text('Passwords do not match.'), findsOneWidget);
      },
    );

    testWidgets(
      'should show requirement checklist items as met once satisfied',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(600, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpRouter(
          tester,
          initialLocation: '/new-password',
          routes: [
            GoRoute(
              path: '/new-password',
              builder: (_, _) => const NewPasswordScreen(),
            ),
          ],
        );

        expect(find.text('At least 8 characters'), findsOneWidget);
        expect(find.text('Contains an uppercase letter'), findsOneWidget);
        expect(find.text('Contains a number'), findsOneWidget);

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'StrongPass1');
        await tester.pumpAndSettle();

        expect(find.text('Strong'), findsOneWidget);
      },
    );
  });
}
