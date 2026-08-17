import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_bar_mock.dart';
import '../../../core/widgets/home_indicator.dart';

const _primaryDarker = Color(0xFF145AC8);
const _primaryLight = Color(0xFFE6F0FF);
const _greenDark = Color(0xFF097044);
const _greenLightBg = Color(0xFFD1FAE5);
const _warningBg = Color(0xFFFEF3C7);
const _warningText = Color(0xFFF59E0B);

class _JoinedActivity {
  const _JoinedActivity({
    required this.id,
    required this.sport,
    required this.title,
    required this.time,
    required this.participants,
    required this.image,
    required this.confirmed,
  });
  final String id;
  final String sport;
  final String title;
  final String time;
  final String participants;
  final String image;
  final bool confirmed;
}

class JoinedActivitiesScreen extends StatefulWidget {
  const JoinedActivitiesScreen({super.key});

  @override
  State<JoinedActivitiesScreen> createState() => _JoinedActivitiesScreenState();
}

class _JoinedActivitiesScreenState extends State<JoinedActivitiesScreen> {
  int _selectedTab = 0;

  static const _activities = [
    _JoinedActivity(
      id: '1',
      sport: 'BASKETBALL',
      title: 'Saturday Afternoon 5v5 Run',
      time: 'Today, 4:00 PM',
      participants: '6/10',
      image: 'basketball_1.png',
      confirmed: true,
    ),
    _JoinedActivity(
      id: '2',
      sport: 'TENNIS',
      title: 'Sunday Singles Play',
      time: 'Tomorrow, 10:00 AM',
      participants: '1/2',
      image: 'tennis_5.png',
      confirmed: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const StatusBarMock(foreground: AppColors.textPrimary),
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    for (final a in _activities)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: _ActivityCard(item: a),
                      ),
                  ],
                ),
              ),
            ),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Activities',
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Notifications',
                child: GestureDetector(
                  onTap: () => context.push('/notifications'),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/images/discovery/icons/bell.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _tabBtn(0, 'Upcoming'),
              _tabBtn(1, 'Past'),
              _tabBtn(2, 'Hosting'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(int index, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? _primaryDarker : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});
  final _JoinedActivity item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/joined-activity/${item.id}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(15, 23, 42, 0.08),
              blurRadius: 12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/discovery/covers/${item.image}',
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.sport,
                          style: AppTypography.bodySmall.copyWith(
                            color: _primaryDarker,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.confirmed ? _greenLightBg : _warningBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.confirmed ? 'CONFIRMED' : 'PENDING',
                          style: AppTypography.bodySmall.copyWith(
                            color: item.confirmed ? _greenDark : _warningText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: SvgPicture.asset(
                          'assets/images/discovery/icons/clock.svg',
                          width: 12,
                          height: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.time,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: SvgPicture.asset(
                          'assets/images/discovery/icons/users.svg',
                          width: 12,
                          height: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.participants,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
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
    );
  }
}