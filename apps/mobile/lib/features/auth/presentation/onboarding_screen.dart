import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';
import '../../../core/widgets/pressable_scale.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      illustration: 'assets/images/onboarding/onb_1.png',
      heading: 'Discover Sports Activities Near You',
      description:
          'Find matches happening in your local neighborhood instantly. From friendly basketball runs to weekend tennis singles.',
    ),
    _OnboardingPage(
      illustration: 'assets/images/onboarding/onb_2.png',
      heading: 'Swipe to Match With Activities',
      description:
          'Find matches that perfectly fit your pace, schedule, and skill level. Simply swipe to browse sports groups.',
    ),
    _OnboardingPage(
      illustration: 'assets/images/onboarding/onb_3.png',
      heading: 'Join, Chat, and Play Together',
      description:
          'Coordination made simple. Live-chat with teammates, lock down the location, and let the games begin.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: AppDurations.emphasized,
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/welcome');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Deliberate deviation from AuthShell (PRD 2.1 principle 1): this screen
    // is full-bleed edge-to-edge illustration with content overlaid on top,
    // structurally incompatible with AuthShell's SafeArea + scroll body.
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return _OnboardingPageView(page: _pages[index]);
            },
          ),
          // Bottom content layer (heading + description + controls + indicator)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: AppSpacing.x6),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x8,
                    ),
                    child: AnimatedSwitcher(
                      duration: AppDurations.base,
                      child: _Content(
                        key: ValueKey(_currentPage),
                        heading: _pages[_currentPage].heading,
                        description: _pages[_currentPage].description,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x5),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x8,
                    ),
                    child: _Pagination(
                      currentPage: _currentPage,
                      totalPages: _pages.length,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x8,
                    ),
                    child: PrimaryPill(
                      label: _currentPage < _pages.length - 1
                          ? 'Next'
                          : 'Get Started',
                      onPressed: _next,
                      icon: 'assets/images/auth/arrow_right.svg',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x8,
                    ),
                    child: Center(
                      child: _SignInPrompt(onTap: () => context.go('/login')),
                    ),
                  ),
                  const HomeIndicator(
                    color: AppColors.textOnPrimary,
                    padding: EdgeInsets.only(
                      top: AppSpacing.x2,
                      bottom: AppSpacing.x2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.page});

  final _OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(page.illustration, fit: BoxFit.cover),
        ),
        // Dark scrim 65% per Figma
        const Positioned.fill(
          child: ColoredBox(color: AppColors.scrimIllustration),
        ),
        // Diagonal gradient overlay (top-left dark → bottom-right transparent)
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.33, 0.67, 1.0],
                colors: [
                  AppColors.scrimGradient,
                  AppColors.scrimGradient,
                  AppColors.scrimTransparent,
                  AppColors.scrimTransparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({super.key, required this.heading, required this.description});

  final String heading;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: AppTypography.headingOnboarding),
        const SizedBox(height: AppSpacing.x4),
        Text(description, style: AppTypography.bodyOnboarding),
      ],
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.currentPage, required this.totalPages});

  final int currentPage;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPages, (i) {
        final isActive = i == currentPage;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x1),
          child: AnimatedContainer(
            duration: AppDurations.base,
            curve: Curves.easeInOut,
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.textOnPrimary,
              borderRadius: AppRadius.pillR,
            ),
          ),
        );
      }),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.x1,
      children: [
        Text(
          'Already have an account?',
          style: AppTypography.bodyOnboarding.copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),
        Semantics(
          button: true,
          label: 'Sign in',
          child: PressableScale(
            onTap: onTap,
            child: Text(
              'Sign In',
              style: AppTypography.bodyOnboarding.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPage {
  const _OnboardingPage({
    required this.illustration,
    required this.heading,
    required this.description,
  });

  final String illustration;
  final String heading;
  final String description;
}
