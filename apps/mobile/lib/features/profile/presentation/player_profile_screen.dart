import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/user_model.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({super.key, required this.playerName});
  final String playerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerProfileProvider(playerName));

    return AppScaffold(
      showHomeIndicator: false, // inside ShellRoute — AppShell draws its own.
      body: playerAsync.when(
        loading: () => const SkeletonList(count: 6),
        error: (_, _) => ErrorRetry(
          message: 'Could not load profile.',
          onRetry: () => ref.invalidate(playerProfileProvider(playerName)),
        ),
        data: (user) {
          if (user == null) {
            return Center(
              child: Text(
                'Player not found.',
                style: AppTypography.bodyReading(
                  context,
                ).copyWith(color: context.colors.textSecondary),
              ),
            );
          }
          return _ProfileContent(user: user);
        },
      ),
    );
  }
}

// ─── Content ─────────────────────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});
  final UserModel user;

  static const double _heroHeight = 160;
  static const double _avatarSize = 88;
  // How far the avatar hangs below the hero edge.
  static const double _avatarOverlap = _avatarSize / 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero + avatar overlap ────────────────────────────────
                SizedBox(
                  height: _heroHeight + _avatarOverlap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Blue gradient cover
                      Container(
                        height: _heroHeight,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primaryDarker,
                              AppColors.primary,
                            ],
                          ),
                        ),
                      ),

                      // Back button
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.x4,
                              vertical: AppSpacing.x1,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _CircleBtn(
                                  icon: Icons.arrow_back_ios_new_rounded,
                                  onTap: () => context.pop(),
                                  label: 'Back',
                                ),
                                _CircleBtn(
                                  icon: Icons.more_horiz_rounded,
                                  onTap: () {},
                                  label: 'More options',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Avatar
                      Positioned(
                        left: AppSpacing.x6,
                        bottom: 0,
                        child: Container(
                          width: _avatarSize,
                          height: _avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colors.primaryLight,
                            border: Border.all(
                              color: context.colors.surface,
                              width: 4,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: user.avatarAsset != null
                              ? Image.asset(
                                  user.avatarAsset!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _AvatarFallback(name: user.displayName),
                                )
                              : _AvatarFallback(name: user.displayName),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Name + location ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x6,
                    AppSpacing.x4,
                    AppSpacing.x6,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: AppTypography.titleScreen(context),
                      ),
                      if (user.location != null || (user.rating ?? 0) > 0) ...[
                        const SizedBox(height: AppSpacing.x1),
                        Row(
                          children: [
                            if ((user.rating ?? 0) > 0) ...[
                              AppIcon(
                                AppIcons.star,
                                size: AppIconSize.sm,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                user.rating!.toStringAsFixed(1),
                                style: AppTypography.countAccent(context)
                                    .copyWith(
                                      color: context.colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                            if ((user.rating ?? 0) > 0 && user.location != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  '·',
                                  style: AppTypography.metaSub(context),
                                ),
                              ),
                            if (user.location != null)
                              Flexible(
                                child: Text(
                                  user.location!,
                                  style: AppTypography.metaSub(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),

                // ── Stats row ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x6,
                  ),
                  child: _StatsRow(
                    activities: user.activitiesCount,
                    rating: user.rating ?? 0,
                    hosted: user.hostedCount,
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),

                // ── Bio ──────────────────────────────────────────────────
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x6,
                    ),
                    child: _Card(
                      title: 'About',
                      child: Text(
                        user.bio!,
                        style: AppTypography.bodyReading(
                          context,
                        ).copyWith(color: context.colors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),
                ],

                // ── Sports ───────────────────────────────────────────────
                if (user.sports.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x6,
                    ),
                    child: _Card(
                      title: 'Sports',
                      child: Wrap(
                        spacing: AppSpacing.x2,
                        runSpacing: AppSpacing.x2,
                        children: user.sports
                            .map(
                              (s) => _SportChip(sport: s.sport, level: s.level),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x5),
                ],

                // ── Action buttons ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          label: 'Message',
                          leading: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: context.colors.textPrimary,
                          ),
                          onPressed: () =>
                              context.push('/chat/${user.displayName}'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: AppButton.danger(
                          label: 'Report',
                          onPressed: () =>
                              context.push('/report/user/${user.displayName}'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    required this.label,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.colors.scrimControl,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: AppColors.textOnPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.primaryLight,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: AppTypography.titleScreen(
          context,
        ).copyWith(color: AppColors.primary, fontSize: 32),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.activities,
    required this.rating,
    required this.hosted,
  });
  final int activities;
  final double rating;
  final int hosted;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(value: '$activities', label: 'Activities'),
          Container(width: 1, height: 36, color: context.colors.border),
          _StatItem(
            value: rating > 0 ? rating.toStringAsFixed(1) : '—',
            label: 'Rating',
          ),
          Container(width: 1, height: 36, color: context.colors.border),
          _StatItem(value: '$hosted', label: 'Hosted'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleScreen(
            context,
          ).copyWith(color: context.colors.primaryOnSurface, fontSize: 20),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.metaSub(context)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.labelField(context)),
            const SizedBox(height: AppSpacing.x3),
            child,
          ],
        ),
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({required this.sport, required this.level});
  final String sport;
  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sport,
            style: AppTypography.labelField(
              context,
            ).copyWith(color: context.colors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.x2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: context.colors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              level,
              style: AppTypography.chipLabel(
                context,
              ).copyWith(color: context.colors.primaryOnSurface),
            ),
          ),
        ],
      ),
    );
  }
}
