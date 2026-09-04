import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/report/data/report_repository.dart';
import 'package:matchup_mobile/features/report/presentation/report_activity_sheet.dart';
import 'package:matchup_mobile/features/report/presentation/report_user_sheet.dart';

class _FakeReportRepository implements ReportRepository {
  int calls = 0;
  String? lastTargetId;
  ReportTargetType? lastTargetType;
  String? lastReason;
  String? lastDetails;

  @override
  Future<void> submit({
    required String targetId,
    required ReportTargetType targetType,
    required String reason,
    String? details,
  }) async {
    calls++;
    lastTargetId = targetId;
    lastTargetType = targetType;
    lastReason = reason;
    lastDetails = details;
  }
}

void main() {
  Future<_FakeReportRepository> pumpSheet(
    WidgetTester tester,
    void Function(BuildContext context) show,
  ) async {
    final fake = _FakeReportRepository();
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reportRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => show(context),
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    return fake;
  }

  group('ReportUserSheet', () {
    testWidgets('renders the target name, reasons and submit button', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        (context) => ReportUserSheet.show(context, userName: 'Jamal Osei'),
      );

      expect(find.text('Report User'), findsOneWidget);
      expect(find.text('Jamal Osei'), findsOneWidget);
      expect(find.text('Harassment'), findsOneWidget);
      expect(find.text('Impersonation'), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
    });

    testWidgets('warns when submitting without a reason', (tester) async {
      final fake = await pumpSheet(
        tester,
        (context) => ReportUserSheet.show(context, userName: 'Jamal Osei'),
      );

      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      expect(fake.calls, 0);
      expect(find.text('Please select a reason.'), findsOneWidget);
      // Sheet stays open so the user can pick a reason.
      expect(find.text('Report User'), findsOneWidget);
    });

    testWidgets('submits the selected reason and closes', (tester) async {
      final fake = await pumpSheet(
        tester,
        (context) => ReportUserSheet.show(context, userName: 'Jamal Osei'),
      );

      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      expect(fake.calls, 1);
      expect(fake.lastTargetId, 'Jamal Osei');
      expect(fake.lastTargetType, ReportTargetType.user);
      expect(fake.lastReason, 'Harassment');
      expect(find.text('Report User'), findsNothing);
      expect(find.text('Report submitted. Thank you.'), findsOneWidget);
    });
  });

  group('ReportActivitySheet', () {
    testWidgets('renders the activity title and reasons', (tester) async {
      await pumpSheet(
        tester,
        (context) =>
            ReportActivitySheet.show(context, activityTitle: 'Morning Run'),
      );

      expect(find.text('Report Activity'), findsOneWidget);
      expect(find.text('Morning Run'), findsOneWidget);
      expect(find.text('Inappropriate content'), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
    });

    testWidgets('submits the selected reason and closes', (tester) async {
      final fake = await pumpSheet(
        tester,
        (context) =>
            ReportActivitySheet.show(context, activityTitle: 'Morning Run'),
      );

      await tester.tap(find.text('Spam / Fake activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();

      expect(fake.calls, 1);
      expect(fake.lastTargetId, 'Morning Run');
      expect(fake.lastTargetType, ReportTargetType.activity);
      expect(fake.lastReason, 'Spam / Fake activity');
      expect(find.text('Report Activity'), findsNothing);
      expect(find.text('Report submitted. Thank you.'), findsOneWidget);
    });
  });
}
