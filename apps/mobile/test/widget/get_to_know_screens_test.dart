import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matchup_mobile/features/preferences/presentation/get_to_know_1_screen.dart';
import 'package:matchup_mobile/features/preferences/presentation/get_to_know_2_screen.dart';

void main() {
  Future<void> pumpRouter(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/get-to-know-1',
      routes: [
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
          builder: (_, _) => const Scaffold(body: Text('Preferences')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  group('GetToKnow1Screen', () {
    testWidgets('should render the step indicator and options', (tester) async {
      await pumpRouter(tester);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Stay active with new sports'), findsOneWidget);
    });

    testWidgets('should push get-to-know-2 when Next is tapped', (
      tester,
    ) async {
      await pumpRouter(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('Which sports do you play?'), findsOneWidget);
    });
  });

  group('GetToKnow2Screen', () {
    testWidgets(
      'should offer "Skip for now" until a sport is selected, then switch to Next',
      (tester) async {
        await pumpRouter(tester);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Skip for now'), findsOneWidget);

        await tester.tap(find.text('Basketball'));
        await tester.pumpAndSettle();

        expect(find.text('Next  (1 selected)'), findsOneWidget);
      },
    );

    testWidgets('should navigate to preferences when the CTA is tapped', (
      tester,
    ) async {
      await pumpRouter(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Skip for now'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('Preferences'), findsOneWidget);
    });
  });
}
