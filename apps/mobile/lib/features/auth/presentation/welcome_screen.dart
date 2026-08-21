import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';
import '../../../core/widgets/pressable_scale.dart';

void _showComingSoon(BuildContext context) {
  AppSnackbar.show(
    context,
    message: 'Social sign-in coming soon.',
    variant: AppSnackbarVariant.info,
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Deliberate deviation from AuthShell (PRD 2.1 principle 1): this screen
    // pins its action buttons to the bottom with a Spacer(), which needs an
    // unbounded, non-scrolling Column — incompatible with AuthShell's
    // SingleChildScrollView body.
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.x3),
            // 2x2 image grid collage (110px height per image, 12px gap, 16px radius)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CollageTile('assets/images/welcome/img_1.png'),
                      const SizedBox(width: AppSpacing.x3),
                      _CollageTile('assets/images/welcome/img_2.png'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Row(
                    children: [
                      _CollageTile('assets/images/welcome/img_3.png'),
                      const SizedBox(width: AppSpacing.x3),
                      _CollageTile('assets/images/welcome/img_4.png'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            // Welcome heading + tagline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
              child: Column(
                children: [
                  Text(
                    'Welcome to MatchUp',
                    textAlign: TextAlign.center,
                    style: AppTypography.headingDisplay(context),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    'Your social app for all things sports',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyFormSecondary(context),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
              child: Column(
                children: [
                  PrimaryPill(
                    label: 'Sign up with email',
                    onPressed: () => context.go('/register'),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  SocialPillButton(
                    label: 'Sign up with Apple',
                    icon: 'assets/images/welcome/apple.svg',
                    onPressed: () => _showComingSoon(context),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  SocialPillButton(
                    label: 'Sign up with Google',
                    icon: 'assets/images/welcome/google.svg',
                    onPressed: () => _showComingSoon(context),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.x2,
                    ),
                    child: Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.x1,
                        children: [
                          Text(
                            'Already have an account?',
                            style: AppTypography.bodyFormSecondary(context),
                          ),
                          Semantics(
                            button: true,
                            label: 'Sign in',
                            child: PressableScale(
                              onTap: () => context.go('/login'),
                              child: Text(
                                'Sign In',
                                style: AppTypography.bodyFormSecondary(context)
                                    .copyWith(
                                      color: context.colors.primaryOnSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }
}

class _CollageTile extends StatelessWidget {
  const _CollageTile(this.path);
  final String path;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: AppRadius.cardR,
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            semanticLabel: 'MatchUp collage image',
          ),
        ),
      ),
    );
  }
}
