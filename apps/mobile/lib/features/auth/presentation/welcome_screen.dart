import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';

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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // 2x2 image grid collage (110px height per image, 12px gap, 16px radius)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CollageTile('assets/images/welcome/img_1.png'),
                      const SizedBox(width: 12),
                      _CollageTile('assets/images/welcome/img_2.png'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _CollageTile('assets/images/welcome/img_3.png'),
                      const SizedBox(width: 12),
                      _CollageTile('assets/images/welcome/img_4.png'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Welcome heading + tagline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    'Welcome to MatchUp',
                    textAlign: TextAlign.center,
                    style: AppTypography.headingDisplay,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your social app for all things sports',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyFormSecondary,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  PrimaryPill(
                    label: 'Sign up with email',
                    onPressed: () => context.go('/register'),
                  ),
                  const SizedBox(height: 12),
                  SocialPillButton(
                    label: 'Sign up with Apple',
                    icon: 'assets/images/welcome/apple.svg',
                    onPressed: () => _showComingSoon(context),
                  ),
                  const SizedBox(height: 12),
                  SocialPillButton(
                    label: 'Sign up with Google',
                    icon: 'assets/images/welcome/google.svg',
                    onPressed: () => _showComingSoon(context),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            'Already have an account?',
                            style: AppTypography.bodyFormSecondary,
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              'Sign In',
                              style: AppTypography.bodyFormSecondary.copyWith(
                                color: AppColors.primaryDarker,
                                fontWeight: FontWeight.w700,
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
            const SizedBox(height: 16),
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
        borderRadius: BorderRadius.circular(16),
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
