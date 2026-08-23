import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matchup_mobile/features/auth/presentation/widgets/auth_shell.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  group('AuthShell', () {
    testWidgets('should render header, children, and bottom slots', (
      tester,
    ) async {
      await pump(
        tester,
        AuthShell(
          header: const Text('Header'),
          bottom: const Text('Bottom'),
          children: const [Text('Body content')],
        ),
      );

      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Body content'), findsOneWidget);
      expect(find.text('Bottom'), findsOneWidget);
    });

    testWidgets(
      'should render children only when header and bottom are omitted',
      (tester) async {
        await pump(tester, const AuthShell(children: [Text('Just body')]));

        expect(find.text('Just body'), findsOneWidget);
      },
    );
  });

  group('AuthCloseButton', () {
    testWidgets('should fire onTap when tapped', (tester) async {
      var tapped = false;
      await pump(tester, AuthCloseButton(onTap: () => tapped = true));

      await tester.tap(find.byType(AuthCloseButton));
      expect(tapped, isTrue);
    });
  });

  group('AuthBackButton and AuthHeaderBar', () {
    testWidgets('should render the title and fire onBack when tapped', (
      tester,
    ) async {
      var backTapped = false;
      await pump(
        tester,
        AuthHeaderBar(
          title: 'Forgot Password',
          onBack: () => backTapped = true,
        ),
      );

      expect(find.text('Forgot Password'), findsOneWidget);
      await tester.tap(find.byType(AuthBackButton));
      expect(backTapped, isTrue);
    });
  });

  group('AuthIllustration', () {
    testWidgets('should render without throwing', (tester) async {
      await pump(
        tester,
        const AuthIllustration(iconPath: 'assets/images/auth/lock.svg'),
      );

      expect(find.byType(AuthIllustration), findsOneWidget);
    });
  });

  group('AuthSignInFooter', () {
    testWidgets('should fire onSignIn when "Sign In" is tapped', (
      tester,
    ) async {
      var tapped = false;
      await pump(tester, AuthSignInFooter(onSignIn: () => tapped = true));

      expect(find.text('Remember your password? '), findsOneWidget);
      await tester.tap(find.text('Sign In'));
      expect(tapped, isTrue);
    });
  });
}
