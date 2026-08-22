import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_state_provider.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/skeleton.dart';
import '../../tour/presentation/tour_controller.dart';
import '../../tour/presentation/tour_steps.dart';
import '../domain/user_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final unreadCount =
        ref.watch(_unreadNotifCountProvider).valueOrNull ?? 0;

    return AppScaffold(
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x3,
              AppSpacing.x5,
              AppSpacing.x4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile',
                        style: AppTypography.headlineLarge(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage your account & games',
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bell button — rounded square
                AppTappable(
                  semanticLabel: 'Notifications',
                  feedback: AppTapFeedback.scale,
                  onTap: () => context.push('/notifications'),
                  minSize: 44,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: context.colors.border),
                      boxShadow: AppShadows.card,
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 22,
                          color: context.colors.textPrimary,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.colors.surface,
                                  width: 1.5,
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

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: profileAsync.when(
              loading: () => const SkeletonList(count: 6),
              error: (_, _) => const Center(
                child: Text('Could not load profile.'),
              ),
              data: (user) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x5,
                  0,
                  AppSpacing.x5,
                  AppSpacing.x8,
                ),
                children: [
                  // Avatar card
                  _AvatarCard(user: user),
                  const SizedBox(height: AppSpacing.x4),

                  // Stats row
                  _StatsRow(user: user),
                  const SizedBox(height: AppSpacing.x5),

                  // My Sports
                  _SportsSection(sports: user.sports),
                  const SizedBox(height: AppSpacing.x5),

                  // Options list
                  _OptionsCard(user: user),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Unread count provider (reused from notifications) ────────────────────────

final _unreadNotifCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final all = await ref.watch(notificationRepositoryProvider).all();
  return all.where((n) => n.unread).length;
});

// ─── Avatar card ──────────────────────────────────────────────────────────────

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final username =
        '@${user.displayName.toLowerCase().replaceAll(' ', '')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x5,
        vertical: AppSpacing.x5,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          // Avatar with edit badge
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar circle with blue border ring
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 3,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: user.avatarAsset != null
                          ? Image.asset(
                              user.avatarAsset!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.primarySoft,
                              child: const Icon(
                                Icons.person,
                                size: 52,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                ),

                // Edit pencil badge
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: AppTappable(
                    semanticLabel: 'Edit profile photo',
                    feedback: AppTapFeedback.scale,
                    minSize: 28,
                    onTap: () => context.push('/edit-profile'),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.colors.surface,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),

          // Name
          Text(
            user.displayName,
            style: AppTypography.headlineSmall(context),
          ),
          const SizedBox(height: 4),

          // @username — blue
          Text(
            username,
            style: AppTypography.bodyMedium(context).copyWith(
              color: context.colors.primaryOnSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            iconWidget: const Icon(
              Icons.people_outline_rounded,
              size: 22,
              color: AppColors.primary,
            ),
            value: '${user.activitiesCount}',
            label: 'Joined',
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: _StatCard(
            iconWidget: Icon(
              Icons.emoji_events_outlined,
              size: 22,
              color: AppColors.success,
            ),
            value: '${user.hostedCount}',
            label: 'Hosted',
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        Expanded(
          child: _StatCard(
            iconWidget: Icon(
              Icons.star_border_rounded,
              size: 22,
              color: AppColors.warning,
            ),
            value: user.rating != null && user.rating! > 0
                ? user.rating!.toStringAsFixed(1)
                : '—',
            label: 'Rating',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.iconWidget,
    required this.value,
    required this.label,
  });

  final Widget iconWidget;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final numeric = double.tryParse(value.replaceAll('—', ''));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          iconWidget,
          const SizedBox(height: AppSpacing.x2),
          numeric != null
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: numeric),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    numeric == numeric.floorToDouble()
                        ? '${v.round()}'
                        : v.toStringAsFixed(1),
                    style: AppTypography.headlineSmall(context).copyWith(
                      fontSize: 22,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: AppTypography.headlineSmall(context).copyWith(
                    fontSize: 22,
                  ),
                ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption(context)),
        ],
      ),
    );
  }
}

// ─── My Sports section ────────────────────────────────────────────────────────

class _SportsSection extends StatelessWidget {
  const _SportsSection({required this.sports});
  final List<({String sport, String level})> sports;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Sports', style: AppTypography.titleMedium(context)),
        const SizedBox(height: AppSpacing.x3),
        if (sports.isEmpty)
          Text(
            'No sports added yet.',
            style: AppTypography.metaSub(context),
          )
        else
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: sports
                .map((s) => _SportPill(sport: s.sport, level: s.level))
                .toList(),
          ),
      ],
    );
  }
}

class _SportPill extends StatelessWidget {
  const _SportPill({required this.sport, required this.level});
  final String sport;
  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            sport,
            style: AppTypography.chipLabel(context).copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          Text(
            ' · $level',
            style: AppTypography.chipLabel(context).copyWith(
              fontWeight: FontWeight.w400,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Options card ─────────────────────────────────────────────────────────────

/// Restarts the first-run tour on demand from Profile, regardless of
/// whether the user has already seen it — `reset` clears the "seen" flag
/// first so `start` (which persists it again on completion/skip) behaves
/// exactly like a fresh first run. Awaiting `reset` before navigating
/// avoids a race where Discovery could mount and check tour state before
/// the flag is actually cleared.
Future<void> _replayTour(BuildContext context, WidgetRef ref) async {
  await ref.read(tourStoreProvider).reset(kFirstRunTourId);
  ref.read(tourControllerProvider.notifier).start(kFirstRunTourId, kFirstRunTour);
  if (context.mounted) context.go('/discovery');
}

class _OptionsCard extends ConsumerWidget {
  const _OptionsCard({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeLabel = switch (themeMode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _OptionRow(
            icon: Icons.person_outline_rounded,
            label: 'Edit Profile',
            onTap: () => context.push('/edit-profile'),
          ),
          _Divider(),
          _OptionRow(
            icon: Icons.calendar_month_outlined,
            label: 'Calendar',
            onTap: () => context.push('/calendar'),
          ),
          _Divider(),
          _OptionRow(
            icon: Icons.notifications_none_rounded,
            label: 'Notification Settings',
            onTap: () => context.push('/notifications'),
          ),
          _Divider(),
          _OptionRow(
            icon: Icons.help_outline_rounded,
            label: 'Replay tour',
            onTap: () {
              _replayTour(context, ref);
            },
          ),
          _Divider(),

          // Appearance row — shows current mode label inline
          _AppearanceRow(
            label: themeLabel,
            themeMode: themeMode,
            onSelect: (m) => ref.read(themeModeProvider.notifier).set(m),
          ),
          _Divider(),

          // Log Out — danger colour, no trailing chevron
          _LogoutRow(),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: context.colors.border, indent: 16, endIndent: 16);
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      semanticLabel: label,
      onTap: onTap,
      minSize: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x5,
          vertical: AppSpacing.x4,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: context.colors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Text(
                label,
                style: AppTypography.labelField(context),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({
    required this.label,
    required this.themeMode,
    required this.onSelect,
  });
  final String label;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onSelect;

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x5,
            AppSpacing.x3,
            AppSpacing.x5,
            AppSpacing.x6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Text('Appearance', style: AppTypography.titleSheet(context)),
              const SizedBox(height: AppSpacing.x4),
              for (final mode in ThemeMode.values)
                _ModeOption(
                  mode: mode,
                  selected: mode == themeMode,
                  onTap: () {
                    onSelect(mode);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      semanticLabel: 'Appearance: $label',
      onTap: () => _showSheet(context),
      minSize: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x5,
          vertical: AppSpacing.x4,
        ),
        child: Row(
          children: [
            Icon(
              Icons.remove_red_eye_outlined,
              size: 22,
              color: context.colors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Text(
                'Appearance',
                style: AppTypography.labelField(context),
              ),
            ),
            Text(
              label,
              style: AppTypography.metaSub(context).copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (mode) {
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_rounded,
  };

  String get _label => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      semanticLabel: _label,
      onTap: onTap,
      minSize: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
        child: Row(
          children: [
            Icon(
              _icon,
              size: 20,
              color: selected
                  ? AppColors.primary
                  : context.colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                _label,
                style: AppTypography.bodyMedium(context).copyWith(
                  color: selected
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 15,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _LogoutRow extends ConsumerWidget {
  const _LogoutRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppTappable(
      semanticLabel: 'Log out',
      onTap: () => _confirmLogout(context, ref),
      minSize: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x5,
          vertical: AppSpacing.x4,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.dangerAccent,
              ),
            ),
            const SizedBox(width: AppSpacing.x4),
            Text(
              'Log Out',
              style: AppTypography.labelField(context).copyWith(
                color: AppColors.dangerAccent,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.dangerAccent.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _LogoutSheet(),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authStateProvider.notifier).signOut();
      if (context.mounted) context.go('/welcome');
    }
  }
}

// ─── Logout confirmation bottom sheet ────────────────────────────────────────

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x4,
        AppSpacing.x5,
        bottomPad + AppSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.logout_rounded,
              size: 26,
              color: AppColors.dangerAccent,
            ),
          ),
          const SizedBox(height: AppSpacing.x3),

          // Title
          Text(
            'Log Out',
            style: AppTypography.titleSheet(context).copyWith(
              color: AppColors.dangerAccent,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),

          // Body
          Text(
            'Are you sure you want to log out of your MatchUp account?',
            textAlign: TextAlign.center,
            style: AppTypography.bodyFormSecondary(context),
          ),
          const SizedBox(height: AppSpacing.x5),

          // Log Out button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerAccent,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Log Out', style: AppTypography.buttonPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),

          // Cancel button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.textPrimary,
                side: BorderSide(color: context.colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.labelField(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
