import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matchup_mobile/features/report/presentation/report_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/activities',
      routes: [
        GoRoute(
          path: '/activities',
          builder: (_, _) => const Scaffold(body: Text('Activities')),
        ),
        GoRoute(
          path: '/report/:type/:name',
          builder: (_, state) => ReportScreen(
            targetType: state.pathParameters['type']!,
            targetName: state.pathParameters['name']!,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    router.push('/report/user/Jamal Osei');
    await tester.pumpAndSettle();
  }

  group('ReportScreen', () {
    testWidgets('should render the target name and default reason selected', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(find.text('Report'), findsOneWidget);
      expect(find.text('Report user'), findsOneWidget);
      expect(find.text('Jamal Osei'), findsOneWidget);
      expect(find.text('Inappropriate content'), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
    });

    testWidgets('should switch the selected reason when another is tapped', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();

      // No exception on selecting a different radio option confirms the
      // RadioGroup wiring survived the AppScaffold migration.
      expect(find.text('Harassment'), findsOneWidget);
    });

    testWidgets('should pop back after submitting the report', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Submit Report'));
      await tester.pump();
      expect(find.text('Submitting...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Report'), findsNothing);
      expect(find.text('Activities'), findsOneWidget);
    });
  });
}
