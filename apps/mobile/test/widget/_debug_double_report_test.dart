import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matchup_mobile/features/report/presentation/report_screen.dart';

CustomTransitionPage<void> appPageNoFix(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
  );
}

void main() {
  testWidgets('reproduce inside ShellRoute with CustomTransitionPage, no fix', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const Text('Home')),
            GoRoute(
              path: '/report/:type/:name',
              pageBuilder: (context, state) {
                final type = state.pathParameters['type'] ?? 'user';
                final name = state.pathParameters['name'] ?? 'Unknown';
                return appPageNoFix(state, ReportScreen(targetType: type, targetName: name));
              },
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/report/activity/1');
    await tester.pumpAndSettle();
    router.push('/report/user/Jamal');
    await tester.pumpAndSettle();

    expect(find.text('Report User'), findsOneWidget);
  });
}
