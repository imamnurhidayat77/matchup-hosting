import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matchup_mobile/features/preferences/presentation/get_to_know_1_screen.dart';
import 'package:matchup_mobile/features/preferences/presentation/get_to_know_2_screen.dart';
import 'package:matchup_mobile/features/preferences/presentation/get_to_know_3_screen.dart';

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
          path: '/get-to-know-3',
          builder: (_, _) => const GetToKnow3Screen(),
        ),
        GoRoute(
          path: '/discovery',
          builder: (_, _) => const Scaffold(body: Text('Discovery')),
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

        // Tapping a chip opens the skill-level sheet; the sport is only
        // added once a level is chosen.
        await tester.tap(find.text('Basketball'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Intermediate'));
        await tester.pumpAndSettle();

        expect(find.text('Next (1 selected)'), findsOneWidget);
      },
    );

    testWidgets(
      'should not add the sport when the skill-level sheet is dismissed',
      (tester) async {
        await pumpRouter(tester);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Basketball'));
        await tester.pumpAndSettle();

        // Dismiss the sheet without choosing a level.
        Navigator.of(tester.element(find.text('Beginner'))).pop();
        await tester.pumpAndSettle();

        expect(find.text('Skip for now'), findsOneWidget);
      },
    );

    testWidgets('should navigate to step 3 when the CTA is tapped', (
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

      expect(find.text('Give us some final details'), findsOneWidget);
    });
  });

  group('GetToKnow3Screen', () {
    testWidgets('should show height, weight and date-of-birth controls', (
      tester,
    ) async {
      await pumpRouter(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Select Weight'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
    });

    testWidgets('should increment the weight when + is tapped', (tester) async {
      await pumpRouter(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(find.text('73'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Increase weight'));
      await tester.pumpAndSettle();

      expect(find.text('74'), findsWidgets);
    });
  });
}
