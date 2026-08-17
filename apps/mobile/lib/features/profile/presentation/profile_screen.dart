import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_controller.dart';

const _primaryDarker = Color(0xFF145AC8);
const _primaryLight = Color(0xFFE6F0FF);
const _bgSurface = Color(0xFFF8FAFC);
const _successBg = Color(0xFFE1F9F1);
const _warningBg = Color(0xFFFFFBEB);
const _logOutColor = Color(0xFFF43F5E);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: const [
            SizedBox(height: 12),
            _Header(),
            SizedBox(height: 16),
            _AvatarHero(),
            SizedBox(height: 16),
            _StatsBoard(),
            SizedBox(height: 16),
            _SportsSection(),
            SizedBox(height: 16),
            _OptionsList(),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.0,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: SvgPicture.asset(
                'assets/images/discovery/icons/notification.svg',
                colorFilter: const ColorFilter.mode(
                  AppColors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarHero extends StatelessWidget {
  const _AvatarHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/discovery/avatars/avatar_alex.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
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
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Alex Mercer',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '@alexmercer',
          style: TextStyle(
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
  const _StatsBoard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: const [
          Expanded(child: _StatCard(value: '24', label: 'Joined', iconAsset: 'assets/images/discovery/icons/users.svg', iconBg: _primaryLight)),
          SizedBox(width: 6),
          Expanded(child: _StatCard(value: '8', label: 'Hosted', iconAsset: 'assets/images/discovery/icons/crown.svg', iconBg: _successBg)),
          SizedBox(width: 6),
          Expanded(child: _StatCard(value: '4.9', label: 'Rating', iconAsset: 'assets/images/discovery/icons/star.svg', iconBg: _warningBg)),
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
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _bgSurface,
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
              colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
            ),
          ),
          const SizedBox(height: 4),
          Text(
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
        color: selected ? _primaryLight : _bgSurface,
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
          color: selected ? _primaryDarker : AppColors.textSecondary,
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
        children: const [
          _OptionRow(
            icon: 'assets/images/discovery/icons/user.svg',
            label: 'Edit Profile',
            route: '/edit-profile',
          ),
          _OptionRow(
            icon: 'assets/images/discovery/icons/calendar.svg',
            label: 'Calendar',
            route: '/calendar',
          ),
          _OptionRow(
            icon: 'assets/images/discovery/icons/bell.svg',
            label: 'Notification Settings',
            route: '/notifications',
          ),
          _ThemeRow(),
          _OptionRow(
            icon: 'assets/images/discovery/icons/power.svg',
            label: 'Log Out',
            labelColor: _logOutColor,
            showChevron: false,
            route: '/welcome',
          ),
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
    this.labelColor,
    this.showChevron = true,
  });

  final String icon;
  final String label;
  final String route;
  final Color? labelColor;
  final bool showChevron;

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
                  colorFilter: ColorFilter.mode(
                    labelColor ?? AppColors.textPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                    color: labelColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (showChevron)
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
