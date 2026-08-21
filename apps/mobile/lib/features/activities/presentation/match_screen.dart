import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../discovery/domain/activity_model.dart';

final _matchActivityProvider = FutureProvider.autoDispose
    .family<ActivityModel, String>((ref, activityId) async {
      final activity = await ref
          .watch(activityRepositoryProvider)
          .byId(activityId);
      if (activity == null) throw StateError('Activity not found');
      return activity;
    });

class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key, required this.activityId});

  final String activityId;

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiCtrl = AnimationController(
    vsync: this,
    duration: AppDurations.emphasized * 5, // ~1.6s celebratory arc
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
    final async = ref.watch(_matchActivityProvider(widget.activityId));

    return AppScaffold(
      backgroundColor: context.colors.surface,
      showHomeIndicator: false, // reached from inside ShellRoute screens.
      body: Stack(
        children: [
          async.when(
            loading: () => const SkeletonList(count: 3),
            error: (_, _) => ErrorRetry(
              message: 'Could not load this match.',
              onRetry: () =>
                  ref.invalidate(_matchActivityProvider(widget.activityId)),
            ),
            data: (activity) => _MatchBody(activity: activity),
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
    );
  }
}

class _MatchBody extends StatelessWidget {
  const _MatchBody({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Column(
          children: [
            const _TopHeader(),
            const SizedBox(height: AppSpacing.x2),
            _MatchCard(activity: activity),
            const SizedBox(height: AppSpacing.x4),
            _Actions(activityId: activity.id),
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x6,
        AppSpacing.x6,
        AppSpacing.x3,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x1 + 2,
            ),
            decoration: BoxDecoration(
              color: context.colors.primaryLight,
              borderRadius: AppRadius.pillR,
            ),
            child: Text(
              'SUCCESS MATCH',
              style: AppTypography.chipLabel(
                context,
              ).copyWith(fontSize: 12, color: context.colors.primaryOnSurface),
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            "It's a Match",
            style: AppTypography.headlineLarge(
              context,
            ).copyWith(color: context.colors.primaryOnSurface),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            "You've been matched to this activity",
            style: AppTypography.bodyFormSecondary(
              context,
            ).copyWith(color: context.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('EEE, h:mm a');
    final fillRatio = activity.capacity == 0
        ? 0.0
        : (activity.participantCount / activity.capacity).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x6,
        vertical: AppSpacing.x2,
      ),
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
                      context.colors.primaryLight.withValues(alpha: 0.7),
                      context.colors.primaryLight.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.floating,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CoverImage(activity: activity),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.x4 + 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: AppTypography.titleLarge(context),
                        ),
                        const SizedBox(height: AppSpacing.x1),
                        Row(
                          children: [
                            const AppIcon(
                              AppIcons.mapPin,
                              size: AppIconSize.sm,
                            ),
                            const SizedBox(width: AppSpacing.x1 + 2),
                            Expanded(
                              child: Text(
                                activity.location,
                                style: AppTypography.chipLabel(
                                  context,
                                ).copyWith(color: context.colors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        Row(
                          children: [
                            _MetaChip(
                              icon: AppIcons.zap,
                              label: activity.skillLevel,
                              color: context.colors.primaryOnSurface,
                            ),
                            const SizedBox(width: AppSpacing.x2),
                            _MetaChip(
                              icon: AppIcons.clock,
                              label: timeFmt.format(activity.dateTime),
                              color: context.colors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        Container(height: 1, color: context.colors.border),
                        const SizedBox(height: AppSpacing.x3),
                        Row(
                          children: [
                            const _AvatarStack(),
                            const SizedBox(width: AppSpacing.x2),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${activity.participantCount} / ${activity.capacity} spots',
                                    style: AppTypography.chipLabel(context),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  const SizedBox(height: 2),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.xs,
                                    ),
                                    child: SizedBox(
                                      height: 5,
                                      child: Stack(
                                        children: [
                                          Container(
                                            color: context.colors.border,
                                          ),
                                          FractionallySizedBox(
                                            widthFactor: fillRatio,
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
                            const SizedBox(width: AppSpacing.x2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.x3,
                                vertical: AppSpacing.x1 + 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.statusSuccessBg,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                              ),
                              child: Text(
                                'Matched',
                                style: AppTypography.chipLabel(context)
                                    .copyWith(
                                      fontSize: 11,
                                      color: AppColors.statusSuccessText,
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
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
            child: Image.asset(
              activity.coverImageUrl ??
                  'assets/images/discovery/covers/basketball_full.png',
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x3 + 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x3,
                    vertical: AppSpacing.x1 + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    activity.sportType.toUpperCase(),
                    style: AppTypography.chipLabel(
                      context,
                    ).copyWith(fontSize: 11, color: AppColors.textOnPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x2 + 2,
                    vertical: AppSpacing.x1 + 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.scrimControl,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppIcons.mapPin,
                        size: AppIconSize.sm,
                        color: context.colors.textOnPrimary,
                      ),
                      const SizedBox(width: AppSpacing.x1),
                      Text(
                        '${activity.distanceKm.toStringAsFixed(1)} km away',
                        style: AppTypography.chipLabel(context).copyWith(
                          fontSize: 11,
                          color: context.colors.textOnPrimary,
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
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final String icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2 + 2,
        vertical: AppSpacing.x1 + 2,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppIconSize.sm, color: color),
          const SizedBox(width: AppSpacing.x1 + 2),
          Text(
            label,
            style: AppTypography.chipLabel(
              context,
            ).copyWith(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

/// Celebratory pair of avatars — the current user's avatar and the activity
/// host's — the two parties of the "match". Kept as initials-in-circles
/// (rather than real photos) since there is no current-user avatar asset,
/// but colours now come from tokens rather than a hardcoded duplicate hex.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 30,
      child: Stack(
        children: [
          const Positioned(left: 0, child: _StackAvatar('avatar_alex.png')),
          Positioned(
            left: 20,
            child: _StackInitial(letter: 'M', color: AppColors.primary),
          ),
          Positioned(
            left: 40,
            child: _StackInitial(letter: 'J', color: AppColors.avatarSecondary),
          ),
        ],
      ),
    );
  }
}

class _StackAvatar extends StatelessWidget {
  const _StackAvatar(this.asset);
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.border, width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/discovery/avatars/$asset',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _StackInitial extends StatelessWidget {
  const _StackInitial({required this.letter, required this.color});
  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: context.colors.border, width: 2),
      ),
      child: Center(
        child: Text(
          letter,
          style: AppTypography.chipLabel(
            context,
          ).copyWith(fontSize: 11, color: AppColors.textOnPrimary),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.activityId});
  final String activityId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x6,
        vertical: AppSpacing.x4,
      ),
      child: Column(
        children: [
          AppButton(
            label: 'View Activity Details',
            onPressed: () {
              HapticFeedback.lightImpact();
              context.go('/joined-activity/$activityId');
            },
            size: AppButtonSize.lg,
          ),
          const SizedBox(height: AppSpacing.x3),
          PressableScale(
            onTap: () => context.go('/discovery'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x3),
              child: Text(
                'Keep Swiping',
                style: AppTypography.labelField(
                  context,
                ).copyWith(color: context.colors.textSecondary, fontSize: 15),
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

// Confetti is decorative celebration content, not a UI surface — using
// AppColors.accent (orange) here alongside primary/warning/success is
// intentional variety for a one-off animation, not the "two competing
// accents" anti-pattern PRD Appendix C.2 warns against for persistent chrome.
const _kConfettiColors = [
  AppColors.primary,
  AppColors.primaryLight,
  AppColors.primaryDarker,
  AppColors.warning,
  AppColors.statusSuccessBg,
  AppColors.accent,
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
