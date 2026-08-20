import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_state_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    // Check session after minimum splash duration so animation completes.
    Future.delayed(const Duration(milliseconds: 2000), _checkSessionAndRoute);
  }

  Future<void> _checkSessionAndRoute() async {
    if (!mounted) return;
    // checkSession() updates authStateProvider which triggers the GoRouter
    // redirect — the router then navigates automatically. We just need to
    // ensure the check is complete before any redirect fires.
    await ref.read(authStateProvider.notifier).checkSession();

    if (!mounted) return;
    final status = ref.read(authStatusProvider);
    if (status == AuthStatus.authenticated) {
      context.go('/discovery');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.splashTop, AppColors.splashBottom],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Decorative SVG dots positioned per Figma (inset % of 390x844)
            const Positioned(
              left: -40,
              top: 120,
              child: _DecorationSvg('assets/images/splash/dot_1.svg', 220),
            ),
            Positioned(
              right: -50,
              top: -40,
              child: _DecorationSvg('assets/images/splash/dot_2.svg', 180),
            ),
            const Positioned(
              left: -50,
              bottom: 120,
              child: _DecorationSvg('assets/images/splash/dot_3.svg', 160),
            ),
            const Positioned(
              right: -40,
              bottom: 80,
              child: _DecorationSvg('assets/images/splash/dot_4.svg', 140),
            ),

            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo badge (96px, rounded 24, soft drop shadow)
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/splash/logo.png',
                              fit: BoxFit.cover,
                              semanticLabel: 'MatchUp logo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('MatchUp', style: AppTypography.wordmarkSplash),
                        const SizedBox(height: 10),
                        Text(
                          'Find Your Game. Meet Your Team.',
                          style: AppTypography.bodyOnboarding.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress bar loader
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 90),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, _) {
                        return Container(
                          width: double.infinity,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _controller.value,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  const HomeIndicator(color: AppColors.textOnPrimary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorationSvg extends StatelessWidget {
  const _DecorationSvg(this.path, this.size);
  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(path, fit: BoxFit.contain),
    );
  }
}