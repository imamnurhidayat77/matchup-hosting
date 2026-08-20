import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matchup_mobile/features/activities/presentation/wizard/components/wizard_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps a widget in the minimal MaterialApp + Directionality needed for pumping.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// resolveVisualState — unit tests (no Flutter needed)
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('resolveVisualState', () {
    test('should return disabled when enabled is false regardless of other flags', () {
      final vs = resolveVisualState(
        enabled: false,
        hasError: true,
        isFocused: true,
        isFilled: true,
      );
      expect(vs, WizardFieldVisualState.disabled);
    });

    test('should return error when enabled and hasError is true', () {
      final vs = resolveVisualState(
        enabled: true,
        hasError: true,
        isFocused: true,
        isFilled: true,
      );
      expect(vs, WizardFieldVisualState.error);
    });

    test('should return focused when enabled, no error, and isFocused is true', () {
      final vs = resolveVisualState(
        enabled: true,
        hasError: false,
        isFocused: true,
        isFilled: true,
      );
      expect(vs, WizardFieldVisualState.focused);
    });

    test('should return filled when enabled, no error, not focused, and isFilled is true', () {
      final vs = resolveVisualState(
        enabled: true,
        hasError: false,
        isFocused: false,
        isFilled: true,
      );
      expect(vs, WizardFieldVisualState.filled);
    });

    test('should return idle when all flags are false', () {
      final vs = resolveVisualState(
        enabled: true,
        hasError: false,
        isFocused: false,
        isFilled: false,
      );
      expect(vs, WizardFieldVisualState.idle);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // WizardFieldLabel
  // ─────────────────────────────────────────────────────────────────────────

  group('WizardFieldLabel', () {
    testWidgets('should render label text', (tester) async {
      await tester.pumpWidget(_wrap(
        const WizardFieldLabel('Activity Title *'),
      ));
      expect(find.text('Activity Title *'), findsOneWidget);
    });

    testWidgets('should render without error when state is idle', (tester) async {
      await tester.pumpWidget(_wrap(
        const WizardFieldLabel('Label', state: WizardFieldVisualState.idle),
      ));
      expect(find.text('Label'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // WizardTextField
  // ─────────────────────────────────────────────────────────────────────────

  group('WizardTextField', () {
    testWidgets('should render label and hint text', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(_wrap(
        WizardTextField(
          label: 'Activity Title *',
          controller: ctrl,
          hint: 'e.g. Weekend Basketball',
        ),
      ));

      expect(find.text('Activity Title *'), findsOneWidget);
      expect(find.text('e.g. Weekend Basketball'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('should call onChanged when text is entered', (tester) async {
      final ctrl = TextEditingController();
      String? changed;

      await tester.pumpWidget(_wrap(
        WizardTextField(
          label: 'Title',
          controller: ctrl,
          hint: 'hint',
          onChanged: (v) => changed = v,
        ),
      ));

      await tester.enterText(find.byType(TextField), 'Morning Run');
      expect(changed, 'Morning Run');
      ctrl.dispose();
    });

    testWidgets('should show error text when errorText is provided', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextField(
          label: 'Title',
          controller: ctrl,
          hint: 'hint',
          errorText: 'Please enter a title',
        ),
      ));

      expect(find.text('Please enter a title'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('should not show error text when errorText is null', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextField(
          label: 'Title',
          controller: ctrl,
          hint: 'hint',
        ),
      ));

      expect(find.text('Please enter a title'), findsNothing);
      ctrl.dispose();
    });

    testWidgets('should render leading icon when provided', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextField(
          label: 'Location',
          controller: ctrl,
          hint: 'hint',
          leadingIcon: Icons.location_on_outlined,
        ),
      ));

      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('should render prefix text when provided', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextField(
          label: 'Price',
          controller: ctrl,
          hint: '0.00',
          prefixText: '\$',
        ),
      ));

      expect(find.text('\$'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('should be disabled when enabled is false', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextField(
          label: 'Title',
          controller: ctrl,
          hint: 'hint',
          enabled: false,
        ),
      ));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
      ctrl.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // WizardTextArea
  // ─────────────────────────────────────────────────────────────────────────

  group('WizardTextArea', () {
    testWidgets('should render label and hint', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextArea(
          label: 'Description',
          controller: ctrl,
          hint: 'Enter a brief description...',
        ),
      ));

      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Enter a brief description...'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('should call onChanged when text is entered', (tester) async {
      final ctrl = TextEditingController();
      String? changed;

      await tester.pumpWidget(_wrap(
        WizardTextArea(
          label: 'Description',
          controller: ctrl,
          hint: 'hint',
          onChanged: (v) => changed = v,
        ),
      ));

      await tester.enterText(find.byType(TextField), 'Fun run');
      expect(changed, 'Fun run');
      ctrl.dispose();
    });

    testWidgets('should show char counter when maxLength is provided', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextArea(
          label: 'Description',
          controller: ctrl,
          hint: 'hint',
          maxLength: 500,
        ),
      ));

      // Initial counter: 0/500
      expect(find.text('0/500'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('should update counter live when text is entered', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextArea(
          label: 'Description',
          controller: ctrl,
          hint: 'hint',
          maxLength: 500,
        ),
      ));

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      expect(find.text('5/500'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('should NOT show counter when maxLength is null', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextArea(
          label: 'Description',
          controller: ctrl,
          hint: 'hint',
        ),
      ));

      // No slash-separated counter text
      final counterFinder = find.textContaining('/');
      expect(counterFinder, findsNothing);
      ctrl.dispose();
    });

    testWidgets('should show error text when errorText is provided', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextArea(
          label: 'Description',
          controller: ctrl,
          hint: 'hint',
          errorText: 'Too long',
        ),
      ));

      expect(find.text('Too long'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('should have minLines respected by TextField', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextArea(
          label: 'Description',
          controller: ctrl,
          hint: 'hint',
          minLines: 3,
        ),
      ));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.minLines, 3);
      ctrl.dispose();
    });

    testWidgets('should align text to top (textAlignVertical.top)', (tester) async {
      final ctrl = TextEditingController();

      await tester.pumpWidget(_wrap(
        WizardTextArea(
          label: 'Description',
          controller: ctrl,
          hint: 'hint',
        ),
      ));

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.textAlignVertical, TextAlignVertical.top);
      ctrl.dispose();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // WizardSelectField
  // ─────────────────────────────────────────────────────────────────────────

  group('WizardSelectField', () {
    testWidgets('should render the value text', (tester) async {
      await tester.pumpWidget(_wrap(
        WizardSelectField(
          value: 'Basketball',
          onTap: () {},
        ),
      ));

      expect(find.text('Basketball'), findsOneWidget);
    });

    testWidgets('should show placeholder when value is empty and placeholder provided',
        (tester) async {
      await tester.pumpWidget(_wrap(
        WizardSelectField(
          value: '',
          placeholder: 'Select a sport',
          onTap: () {},
        ),
      ));

      expect(find.text('Select a sport'), findsOneWidget);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(_wrap(
        WizardSelectField(
          value: 'Tennis',
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(WizardSelectField));
      expect(tapped, isTrue);
    });

    testWidgets('should NOT call onTap when disabled', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(_wrap(
        WizardSelectField(
          value: 'Tennis',
          onTap: () => tapped = true,
          enabled: false,
        ),
      ));

      await tester.tap(find.byType(WizardSelectField));
      expect(tapped, isFalse);
    });

    testWidgets('should render leading icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        WizardSelectField(
          value: 'Monday',
          leadingIcon: Icons.calendar_today_outlined,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    });

    testWidgets('should render chevron icon', (tester) async {
      await tester.pumpWidget(_wrap(
        WizardSelectField(
          value: 'Running',
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });
  });
}
