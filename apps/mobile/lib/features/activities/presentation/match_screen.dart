import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/home_indicator.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    // Start confetti + haptic burst on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.heavyImpact();
      _confettiCtrl.forward();
    });
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: true,
        child: Stack(
          children: [
            Column(
              children: [
                _topHeader(),
                Expanded(child: _card(context)),
                _actions(context),
                const HomeIndicator(),
              ],
            ),
            Positioned.fill(
              top: 80,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiCtrl,
                  builder: (_, _) =>
                      _ConfettiLayer(progress: _confettiCtrl.value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'SUCCESS MATCH',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryDarker,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "It's a Match!",
            style: AppTypography.headlineLarge.copyWith(
              fontSize: 32,
              color: AppColors.primaryDarker,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You've been matched to this activity",
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 30,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryLight.withValues(alpha: 0.7),
                      AppColors.primaryLight.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppShadows.floating,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _coverImage(),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sunset Basketball 5v5',
                          style: AppTypography.headlineSmall.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: SvgPicture.asset(
                                'assets/images/discovery/icons/map_pin.svg',
                                width: 14,
                                height: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Brooklyn Public Courts',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _metaChip(
                              'zap.svg',
                              'Intermediate',
                              AppColors.primaryDarker,
                            ),
                            const SizedBox(width: 8),
                            _metaChip(
                              'clock.svg',
                              'Today, 6:30 PM',
                              AppColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: AppColors.border),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _avatarStack(),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '8 / 12 spots',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 2),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: SizedBox(
                                      height: 5,
                                      child: Stack(
                                        children: [
                                          Container(color: AppColors.border),
                                          FractionallySizedBox(
                                            widthFactor: 0.67,
                                            child: Container(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusSuccessBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Matched',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.statusSuccessText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverImage() {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Image.asset(
              'assets/images/discovery/covers/basketball_full.png',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'BASKETBALL',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(0, 0, 0, 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: SvgPicture.asset(
                          'assets/images/discovery/icons/map_pin.svg',
                          width: 12,
                          height: 12,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '2.5 km away',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: SvgPicture.asset(
              'assets/images/discovery/icons/$icon',
              width: 13,
              height: 13,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarStack() {
    return SizedBox(
      width: 70,
      height: 30,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _avatar('avatar_alex.png', borderColor: AppColors.border),
          ),
          Positioned(
            left: 20,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: const Center(
                child: Text(
                  'M',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 40,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF097044),
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: const Center(
                child: Text(
                  'J',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String asset, {required Color borderColor}) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/discovery/avatars/$asset',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          AppButton(
            label: 'View Activity Details',
            onPressed: () {
              HapticFeedback.lightImpact();
              context.go('/joined-activity/1');
            },
            size: AppButtonSize.lg,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.go('/discovery'),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Keep Swiping',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated confetti layer ──────────────────────────────────────────────────

class _ConfettiParticle {
  _ConfettiParticle(math.Random rng, double width, double height)
    : x = rng.nextDouble() * width,
      y = -20 - rng.nextDouble() * height * 0.3,
      size = 6 + rng.nextDouble() * 8,
      speedY = 180 + rng.nextDouble() * 260,
      speedX = (rng.nextDouble() - 0.5) * 80,
      rotation = rng.nextDouble() * math.pi * 2,
      rotationSpeed = (rng.nextDouble() - 0.5) * 6,
      color = _kConfettiColors[rng.nextInt(_kConfettiColors.length)],
      isCircle = rng.nextBool();

  final double x;
  final double y;
  final double size;
  final double speedY;
  final double speedX;
  final double rotation;
  final double rotationSpeed;
  final Color color;
  final bool isCircle;
}

const _kConfettiColors = [
  AppColors.primary,
  AppColors.primaryLight,
  AppColors.primaryDarker,
  AppColors.warning,
  AppColors.statusSuccessBg,
  Color(0xFFFFD700), // gold
];

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer({required this.progress});

  /// 0.0 → 1.0 from the parent AnimationController.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rng = math.Random(99); // fixed seed for determinism
    final particles = List.generate(
      30,
      (_) => _ConfettiParticle(rng, size.width, size.height),
    );

    return Stack(
      children: particles.map((p) {
        // Each particle falls at its own speed; some lead, some lag.
        final elapsed = progress * 1.8; // seconds equivalent
        final py = p.y + p.speedY * elapsed;
        final px = p.x + p.speedX * elapsed;
        final rot = p.rotation + p.rotationSpeed * elapsed;
        // Fade out in the last 30% of progress
        final opacity = (1 - ((progress - 0.7) / 0.3).clamp(0.0, 1.0)).clamp(
          0.0,
          1.0,
        );

        return Positioned(
          left: px,
          top: py,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: rot,
              child: Container(
                width: p.size,
                height: p.size,
                decoration: BoxDecoration(
                  shape: p.isCircle ? BoxShape.circle : BoxShape.rectangle,
                  color: p.color,
                  borderRadius: p.isCircle
                      ? null
                      : BorderRadius.circular(p.size * 0.2),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
