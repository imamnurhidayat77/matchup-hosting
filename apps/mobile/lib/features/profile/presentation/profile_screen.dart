import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_state_provider.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/notification_icon_button.dart';
import '../../../core/widgets/skeleton.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: profileAsync.when(
          loading: () => const SkeletonList(count: 6),
          error: (_, _) => const Center(child: Text('Could not load profile.')),
          data: (user) => ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 12),
              _Header(
                onNotificationTap: () => context.push('/notifications'),
              ),
              const SizedBox(height: 16),
              _AvatarHero(
                displayName: user.displayName,
                avatarAsset: user.avatarAsset,
                onEditTap: () => context.push('/edit-profile'),
              ),
              const SizedBox(height: 16),
              _StatsBoard(
                joined: 24, // TODO: from activity repository
                hosted: 8,  // TODO: from activity repository
                rating: user.rating ?? 0.0,
              ),
              const SizedBox(height: 16),
              const _SportsSection(),
              const SizedBox(height: 16),
              const _OptionsList(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNotificationTap});
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Profile', style: AppTypography.titleScreen),
          NotificationIconButton(onTap: onNotificationTap),
        ],
      ),
    );
  }
}

class _AvatarHero extends StatelessWidget {
  const _AvatarHero({
    required this.displayName,
    this.avatarAsset,
    this.onEditTap,
  });

  final String displayName;
  final String? avatarAsset;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    final username = '@${displayName.toLowerCase().replaceAll(' ', '')}';
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: onEditTap,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarAsset != null
                      ? Image.asset(avatarAsset!, fit: BoxFit.cover)
                      : const Icon(Icons.person, size: 60, color: AppColors.primary),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: onEditTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/discovery/icons/edit.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          displayName,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          username,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatsBoard extends StatelessWidget {
  const _StatsBoard({
    required this.joined,
    required this.hosted,
    required this.rating,
  });

  final int joined;
  final int hosted;
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '$joined',
              label: 'Joined',
              iconAsset: 'assets/images/discovery/icons/users.svg',
              iconBg: AppColors.primarySoft,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _StatCard(
              value: '$hosted',
              label: 'Hosted',
              iconAsset: 'assets/images/discovery/icons/crown.svg',
              iconBg: AppColors.successBg,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _StatCard(
              value: rating > 0 ? rating.toStringAsFixed(1) : '—',
              label: 'Rating',
              iconAsset: 'assets/images/discovery/icons/star.svg',
              iconBg: AppColors.warningBg,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.iconAsset,
    required this.iconBg,
  });

  final String value;
  final String label;
  final String iconAsset;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    // Parse numeric value for count-up animation; fall back to static text.
    final numericValue = double.tryParse(value.replaceAll('—', ''));

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              iconAsset,
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
          const SizedBox(height: 4),
          numericValue != null
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: numericValue),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Text(
                    numericValue == numericValue.floorToDouble()
                        ? '${v.round()}'
                        : v.toStringAsFixed(1),
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      color: AppColors.textPrimary,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: AppColors.textPrimary,
                  ),
                ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.0,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SportsSection extends StatelessWidget {
  const _SportsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MY SPORTS',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SportBadge(label: 'Basketball 🏀', selected: true),
              _SportBadge(label: 'Tennis 🎾', selected: true),
              _SportBadge(label: 'Running 🏃‍♂️', selected: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _SportBadge extends StatelessWidget {
  const _SportBadge({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.0,
          color: selected ? AppColors.primaryDarker : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _OptionsList extends StatelessWidget {
  const _OptionsList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const _OptionRow(
            icon: 'assets/images/discovery/icons/user.svg',
            label: 'Edit Profile',
            route: '/edit-profile',
          ),
          const _OptionRow(
            icon: 'assets/images/discovery/icons/calendar.svg',
            label: 'Calendar',
            route: '/calendar',
          ),
          const _OptionRow(
            icon: 'assets/images/discovery/icons/bell.svg',
            label: 'Notification Settings',
            route: '/notifications',
          ),
          const _ThemeRow(),
          _LogoutRow(),
        ],
      ),
    );
  }
}

class _ThemeRow extends ConsumerWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final label = switch (mode) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/images/discovery/icons/preferences.svg',
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(
                  AppColors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Appearance',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          PopupMenuButton<ThemeMode>(
            tooltip: 'Theme',
            initialValue: mode,
            onSelected: (m) =>
                ref.read(themeModeProvider.notifier).set(m),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ThemeMode.light,
                child: Row(children: [
                  Icon(Icons.light_mode, size: 18),
                  SizedBox(width: 8),
                  Text('Light'),
                ]),
              ),
              PopupMenuItem(
                value: ThemeMode.dark,
                child: Row(children: [
                  Icon(Icons.dark_mode, size: 18),
                  SizedBox(width: 8),
                  Text('Dark'),
                ]),
              ),
              PopupMenuItem(
                value: ThemeMode.system,
                child: Row(children: [
                  Icon(Icons.brightness_auto, size: 18),
                  SizedBox(width: 8),
                  Text('System'),
                ]),
              ),
            ],
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDarker,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.route,
  });

  final String icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  icon,
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (true)
              SvgPicture.asset(
                'assets/images/discovery/icons/chevron_down.svg',
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  AppColors.textTertiary,
                  BlendMode.srcIn,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Logout row — confirms before clearing tokens and navigating to welcome.
class _LogoutRow extends ConsumerWidget {
  const _LogoutRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _confirmLogout(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/images/discovery/icons/power.svg',
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                AppColors.dangerAccent,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Log Out',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.0,
                color: AppColors.dangerAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.dangerAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Clear tokens from secure storage → authStateProvider triggers router
    // redirect → GoRouter navigates to /welcome automatically.
    await ref.read(authStateProvider.notifier).signOut();
  }
}
