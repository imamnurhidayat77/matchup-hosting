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
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../discovery/domain/activity_model.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _matchActivityProvider = FutureProvider.autoDispose
    .family<ActivityModel, String>((ref, activityId) async {
  final activity =
      await ref.watch(activityRepositoryProvider).byId(activityId);
  if (activity == null) throw StateError('Activity not found');
  return activity;
});

// ─── Screen ──────────────────────────────────────────────────────────────────

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
    duration: AppDurations.emphasized * 5,
  );

  @override
  void initState() {
    super.initState();
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
      backgroundColor: context.colors.background,
      showHomeIndicator: false,
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
          // Confetti overlay
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

// ─── Body ─────────────────────────────────────────────────────────────────────

class _MatchBody extends StatelessWidget {
  const _MatchBody({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x5,
          AppSpacing.x5,
          AppSpacing.x5,
          AppSpacing.x6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // SUCCESS MATCH badge — outlined pill
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.extension_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SUCCESS MATCH',
                    style: AppTypography.chipLabel(context).copyWith(
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),

            // ⭐ It's a Match! ⭐
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.star_border_rounded,
                    size: 32, color: AppColors.warning),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  "It's a Match!",
                  style: AppTypography.headlineLarge(context),
                ),
                const SizedBox(width: AppSpacing.x2),
                const Icon(Icons.star_border_rounded,
                    size: 32, color: AppColors.warning),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),

            // Subtitle
            Text(
              "You've been matched to this activity",
              style: AppTypography.bodyFormSecondary(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x5),

            // Activity card
            _ActivityCard(activity: activity),
            const SizedBox(height: AppSpacing.x5),

            // View Activity Details — full-width blue pill
            PressableScale(
              onTap: () {
                HapticFeedback.lightImpact();
                context.go('/joined-activity/${activity.id}');
              },
              child: Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadows.glowPrimary,
                ),
                alignment: Alignment.center,
                child: Text(
                  'View Activity Details',
                  style: AppTypography.buttonPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),

            // Keep Swiping — underlined blue link
            Semantics(
              button: true,
              label: 'Keep swiping',
              child: PressableScale(
                onTap: () => context.go('/discovery'),
                child: Text(
                  'Keep Swiping',
                  style: AppTypography.labelField(context).copyWith(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Activity card ────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('EEE, h:mm a');
    final fillRatio = activity.capacity == 0
        ? 0.0
        : (activity.participantCount / activity.capacity).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image with badges
          _CoverImage(activity: activity),

          // Card body
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  activity.title,
                  style: AppTypography.titleLarge(context),
                ),
                const SizedBox(height: AppSpacing.x1),

                // Location row
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 15,
                      color: context.colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activity.location,
                        style: AppTypography.metaSub(context).copyWith(
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),

                // Skill + time chips
                Row(
                  children: [
                    _MetaChip(
                      icon: Icons.shield_outlined,
                      label: activity.skillLevel,
                      isBlue: true,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    _MetaChip(
                      icon: Icons.access_time_rounded,
                      label: timeFmt.format(activity.dateTime),
                      isBlue: false,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x3),

                Divider(height: 1, color: context.colors.border),
                const SizedBox(height: AppSpacing.x3),

                // Participants row
                Row(
                  children: [
                    // Avatar stack
                    _AvatarStack(),
                    const SizedBox(width: AppSpacing.x2),

                    // Spots count
                    Expanded(
                      child: Text(
                        '${activity.participantCount} / ${activity.capacity} spots',
                        style: AppTypography.chipLabel(context),
                      ),
                    ),

                    // Matched badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x3,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusSuccessBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'Matched',
                        style: AppTypography.chipLabel(context).copyWith(
                          color: AppColors.statusSuccessText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(color: context.colors.border),
                        FractionallySizedBox(
                          widthFactor: fillRatio,
                          child: Container(color: AppColors.primary),
                        ),
                      ],
                    ),
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

// ─── Cover image ──────────────────────────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Image.asset(
              activity.coverImageUrl ??
                  'assets/images/discovery/covers/basketball_full.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.primaryDark,
                child: const Center(
                  child: Icon(Icons.sports, size: 48,
                      color: AppColors.textOnPrimary),
                ),
              ),
            ),

            // Badges top row
            Positioned(
              top: AppSpacing.x3,
              left: AppSpacing.x3,
              right: AppSpacing.x3,
              child: Row(
                children: [
                  // Sport — white pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.textOnPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      activity.sportType.toUpperCase(),
                      style: AppTypography.chipLabel(context).copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  // Distance — blue pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${activity.distanceKm.toStringAsFixed(1)} KM AWAY',
                      style: AppTypography.chipLabel(context).copyWith(
                        color: AppColors.textOnPrimary,
                        fontSize: 11,
                      ),
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

// ─── Meta chip ────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.isBlue,
  });
  final IconData icon;
  final String label;
  final bool isBlue;

  @override
  Widget build(BuildContext context) {
    final color =
        isBlue ? context.colors.primaryOnSurface : context.colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isBlue ? AppColors.primarySoft : context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isBlue
              ? AppColors.primary.withValues(alpha: 0.3)
              : context.colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.chipLabel(context).copyWith(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar stack ─────────────────────────────────────────────────────────────

class _AvatarStack extends StatelessWidget {
  const _AvatarStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 28,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: _avatarImg('avatar_alex.png', context),
          ),
          Positioned(
            left: 20,
            child: _avatarInitial('M', AppColors.primary, context),
          ),
          Positioned(
            left: 40,
            child: _avatarInitial('J', AppColors.avatarSecondary, context),
          ),
        ],
      ),
    );
  }

  Widget _avatarImg(String asset, BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.surface, width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/discovery/avatars/$asset',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Container(color: AppColors.primarySoft),
        ),
      ),
    );
  }

  Widget _avatarInitial(String letter, Color color, BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: context.colors.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: AppTypography.chipLabel(context).copyWith(
          fontSize: 11,
          color: AppColors.textOnPrimary,
        ),
      ),
    );
  }
}

// ─── Confetti ─────────────────────────────────────────────────────────────────

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

  final double x, y, size, speedY, speedX, rotation, rotationSpeed;
  final Color color;
  final bool isCircle;
}

const _kConfettiColors = [
  AppColors.primary,
  AppColors.primaryLight,
  AppColors.warning,
  AppColors.statusSuccessBg,
  AppColors.accent,
];

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rng = math.Random(99);
    final particles = List.generate(
      30,
      (_) => _ConfettiParticle(rng, size.width, size.height),
    );

    return Stack(
      children: particles.map((p) {
        final elapsed = progress * 1.8;
        final px = p.x + p.speedX * elapsed;
        final py = p.y + p.speedY * elapsed;
        final rot = p.rotation + p.rotationSpeed * elapsed;
        final opacity =
            (1 - ((progress - 0.7) / 0.3).clamp(0.0, 1.0)).clamp(0.0, 1.0);

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
