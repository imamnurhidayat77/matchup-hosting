import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';

const _primaryDarker = Color(0xFF145AC8);
const _primaryLight = Color(0xFFE6F0FF);
const _bgSurface = Color(0xFFF8FAFC);
const _errorText = Color(0xFFCC3333);

class ActivityDetailScreen extends StatelessWidget {
  final String activityId;

  const ActivityDetailScreen({super.key, required this.activityId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _hero(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerInfo(),
                    const SizedBox(height: 16),
                    _skillChip(),
                    const SizedBox(height: 16),
                    _hostRow(),
                    const SizedBox(height: 12),
                    _metaItem(
                      icon: 'calendar.svg',
                      title: 'Saturday, October 24',
                      sub: '4:00 PM - 6:00 PM',
                    ),
                    const SizedBox(height: 12),
                    _metaItem(
                      icon: 'map_pin.svg',
                      title: 'Brooklyn Public Courts',
                      sub: 'Court #3, Prospect Park, NY',
                    ),
                    const SizedBox(height: 16),
                    _about(),
                    const SizedBox(height: 16),
                    _participants(),
                    const SizedBox(height: 16),
                    _reportButton(context),
                  ],
                ),
              ),
            ),
            _actionBar(context),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/discovery/covers/basketball_full.png',
            fit: BoxFit.cover,
            semanticLabel: 'Basketball court',
          ),
          Container(color: const Color.fromRGBO(0, 0, 0, 0.4)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 44),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        'assets/images/discovery/icons/arrow_left.svg',
                        Icons.arrow_back,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      _circleButton(
                        'assets/images/discovery/icons/share.svg',
                        Icons.share,
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

  Widget _circleButton(String assetPath, IconData fallback, {VoidCallback? onTap}) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(0, 0, 0, 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            width: 20,
            height: 20,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              child: SvgPicture.asset(assetPath, width: 20, height: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primaryLight,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            'BASKETBALL',
            style: AppTypography.bodySmall.copyWith(
              color: _primaryDarker,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sunset Basketball 5v5',
          style: AppTypography.headlineSmall.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _skillChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bgSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: SvgPicture.asset(
              'assets/images/discovery/icons/zap.svg',
              width: 13,
              height: 13,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'INTERMEDIATE',
            style: AppTypography.bodySmall.copyWith(
              color: _primaryDarker,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hostRow() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/discovery/avatars/avatar_alex.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alex Mercer',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Host',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 14,
            height: 14,
            child: SvgPicture.asset(
              'assets/images/discovery/icons/star.svg',
              width: 14,
              height: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '4.9',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaItem({
    required String icon,
    required String title,
    required String sub,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryLight,
            borderRadius: BorderRadius.circular(100),
          ),
          child: SizedBox(
            width: 18,
            height: 18,
            child: SvgPicture.asset(
              'assets/images/discovery/icons/$icon',
              width: 18,
              height: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                sub,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _about() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About this Activity',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Looking for intermediate players to join us for some friendly full-court 5v5 runs. We usually play 3 matches, bring a black and white jersey if you can. Water is provided!',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _participants() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Participants',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '6 joined / 10 total',
              style: AppTypography.bodyMedium.copyWith(
                color: _primaryDarker,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 32,
          child: Row(
            children: [
              _avatar('avatar_1.png'),
              _avatar('avatar_2.png', overlap: 10),
              _avatar('avatar_3.png', overlap: 10),
              _avatar('avatar_4.png', overlap: 10),
              _moreAvatar('+2', overlap: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar(String asset, {double overlap = 0}) {
    return Padding(
      padding: EdgeInsets.only(right: overlap),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/discovery/avatars/$asset',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _moreAvatar(String label, {double overlap = 0}) {
    return Padding(
      padding: EdgeInsets.only(right: overlap),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.border,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _reportButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/report/activity/$activityId'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: SvgPicture.asset(
                'assets/images/discovery/icons/alert_circle.svg',
                width: 18,
                height: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Report Activity',
              style: AppTypography.bodyMedium.copyWith(
                color: _errorText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: 'Pass',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.05),
                      blurRadius: 10,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: SvgPicture.asset(
                      'assets/images/discovery/icons/x_circle.svg',
                      width: 26,
                      height: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Semantics(
            button: true,
            label: 'Join activity',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/joined-activity/$activityId'),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(45, 127, 249, 0.25),
                      blurRadius: 10,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: SvgPicture.asset(
                      'assets/images/discovery/icons/heart.svg',
                      width: 26,
                      height: 26,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}