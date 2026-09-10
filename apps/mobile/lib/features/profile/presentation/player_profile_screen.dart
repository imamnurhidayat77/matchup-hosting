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
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/asset_image.dart';
import '../../../core/widgets/error_retry.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/skeleton.dart';
import '../../report/presentation/report_user_sheet.dart';
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

  static const double _avatarSize = 110;
  static const double _avatarRingWidth = 3;
  static const double _avatarRingGap = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar: back + more ─────────────────────────────────
                Padding(
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

                // ── Avatar ────────────────────────────────────────────────
                Center(
                  child: Container(
                    width:
                        _avatarSize +
                        2 * (_avatarRingWidth + _avatarRingGap),
                    height:
                        _avatarSize +
                        2 * (_avatarRingWidth + _avatarRingGap),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.primaryOnSurface,
                        width: _avatarRingWidth,
                      ),
                    ),
                    padding: const EdgeInsets.all(_avatarRingGap),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.primaryLight,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (user.avatarUrl ?? user.avatarAsset) != null
                          ? AssetImageWithFallback(
                              imagePath:
                                  user.avatarUrl ?? user.avatarAsset!,
                              fit: BoxFit.cover,
                            )
                          : _AvatarFallback(name: user.displayName),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),

                // ── Name ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x6,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      user.displayName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: AppTypography.titleScreen(context).copyWith(
                        fontSize: 24,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // ── Location ──────────────────────────────────────────────
                if (user.location != null) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          AppIcons.mapPin,
                          size: AppIconSize.sm,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.location!,
                          style: AppTypography.metaSub(context),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.x5),

                // ── Stat cards ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          valueWidget: Text(
                            '${user.activitiesCount}',
                            style: _StatCard.valueStyle(context),
                          ),
                          label: 'Activities',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: _StatCard(
                          valueWidget: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(
                                AppIcons.star,
                                size: AppIconSize.sm,
                                color: context.colors.warningText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (user.rating ?? 0) > 0
                                    ? user.rating!.toStringAsFixed(1)
                                    : '—',
                                style: _StatCard.valueStyle(context),
                              ),
                            ],
                          ),
                          label: 'Rating',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      Expanded(
                        child: _StatCard(
                          valueWidget: Text(
                            '${user.hostedCount}',
                            style: _StatCard.valueStyle(context),
                          ),
                          label: 'Hosted',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),

                // ── Bio ──────────────────────────────────────────────────
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bio', style: AppTypography.titleMedium(context)),
                        const SizedBox(height: AppSpacing.x3),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.x4),
                          decoration: BoxDecoration(
                            color: context.colors.card,
                            borderRadius: AppRadius.cardR,
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Text(
                            user.bio!,
                            style: AppTypography.bodyReading(
                              context,
                            ).copyWith(color: context.colors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x5),
                ],

                // ── Sports ───────────────────────────────────────────────
                if (user.sports.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Sports',
                          style: AppTypography.titleMedium(context),
                        ),
                        const SizedBox(height: AppSpacing.x3),
                        Wrap(
                          spacing: AppSpacing.x2,
                          runSpacing: AppSpacing.x2,
                          children: [
                            for (var i = 0; i < user.sports.length; i++)
                              _SportChip(
                                sport: user.sports[i].sport,
                                level: user.sports[i].level,
                                isPrimary: i == 0,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                ],

                // ── Action buttons ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x6,
                  ),
                  child: Column(
                    children: [
                      AppButton(
                        label: 'Send Message',
                        leading: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: AppColors.textOnPrimary,
                        ),
                        // Direct messages aren't supported yet — the
                        // backend's chat is per-activity, not per-user.
                        // Disable the button until DMs land. Wired to
                        // a TODO marker so it's easy to find when
                        // adding `/api/dm/:uid` later.
                        onPressed: null,
                      ),
                      const SizedBox(height: AppSpacing.x3),
                      AppButton.secondary(
                        label: 'Report Profile',
                        leading: Icon(
                          Icons.flag_outlined,
                          size: 18,
                          color: context.colors.textPrimary,
                        ),
                        onPressed: () => ReportUserSheet.show(
                          context,
                          userId: user.id,
                          userName: user.displayName,
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
                color: context.colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.border),
                boxShadow: AppShadows.card,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: context.colors.textPrimary),
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
        ).copyWith(color: context.colors.primaryOnSurface, fontSize: 32),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.valueWidget, required this.label});
  final Widget valueWidget;
  final String label;

  static TextStyle valueStyle(BuildContext context) =>
      AppTypography.titleScreen(
        context,
      ).copyWith(fontSize: 18, color: context.colors.textPrimary);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.x3,
        horizontal: AppSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: AppRadius.cardR,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          valueWidget,
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.metaSub(context).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.sport,
    required this.level,
    required this.isPrimary,
  });
  final String sport;
  final String level;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: context.colors.surface,
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
              color: isPrimary
                  ? context.colors.primarySoft
                  : context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              level.toUpperCase(),
              style: AppTypography.chipLabel(context).copyWith(
                color: isPrimary
                    ? context.colors.primaryOnSurface
                    : context.colors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
