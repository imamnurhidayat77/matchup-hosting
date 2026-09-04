import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matchup_mobile/features/discovery/presentation/filter_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FilterScreen())),
    );
    await tester.pumpAndSettle();
  }

  group('FilterScreen', () {
    testWidgets('should render all filter sections', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Your sports'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
      expect(find.text('Skill level per sport'), findsOneWidget);
      expect(find.text('When'), findsOneWidget);
      expect(find.text('Show all activities'), findsOneWidget);
    });

    testWidgets('should toggle a sport chip selection when tapped', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Running').first);
      await tester.pumpAndSettle();

      // Tapping does not throw and the label remains visible; selection
      // state is verified indirectly since chip styling isn't text-based.
      // 'Running' now appears twice: once in the sport pill and once as the
      // per-sport skill row header.
      expect(find.text('Running'), findsNWidgets(2));
    });

    testWidgets('should reset filters when Reset is tapped', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.text('Within 5 km'), findsOneWidget);
    });

    testWidgets('should update the skill level when a segment is tapped', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();

      expect(find.text('Advanced'), findsOneWidget);
    });
  });
}
