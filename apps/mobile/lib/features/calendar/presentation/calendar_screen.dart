import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/notification_icon_button.dart';
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _viewMonth;
  late int? _selectedDay;
  static const _activityDays = <int>{4, 7, 8, 12, 15, 20, 22, 31};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(now.year, now.month);
    _selectedDay = now.day; // default to today
  }

  void _shiftMonth(int delta) {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + delta);
      _selectedDay = null; // clear selection when switching month
    });
  }

  void _selectDay(int day, bool faded) {
    if (faded) return;
    setState(() => _selectedDay = _selectedDay == day ? null : day);
  }

  String _monthLabel() {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${names[_viewMonth.month - 1]} ${_viewMonth.year}';
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Today, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isCurrentMonth =
        today.year == _viewMonth.year && today.month == _viewMonth.month;
    final firstOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final leading = firstOfMonth.weekday % 7;
    final prevMonthDays = DateTime(_viewMonth.year, _viewMonth.month, 0).day;
    final rows = ((leading + daysInMonth + 6) ~/ 7);

    final cells = <_DayCell>[];
    for (var i = 0; i < leading; i++) {
      cells.add(_DayCell(day: prevMonthDays - leading + i + 1, faded: true));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final isToday = isCurrentMonth && d == today.day;
      cells.add(_DayCell(
        day: d,
        isToday: isToday,
        hasActivity: _activityDays.contains(d),
        isSelected: _selectedDay == d,
        onTap: () => _selectDay(d, false),
      ));
    }
    var nextDay = 1;
    while (cells.length < rows * 7) {
      cells.add(_DayCell(day: nextDay++, faded: true));
    }

    // Filter agenda by selected day
    final showingAllDay = _selectedDay == null;
    final hasActivitiesOnDay =
        _selectedDay != null && _activityDays.contains(_selectedDay);

    final dateLabel = _selectedDay != null
        ? '${_monthLabel()}, $_selectedDay'
        : _todayLabel();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopNav(onNotificationTap: () => context.push('/notifications')),
            _MonthNav(
              label: _monthLabel(),
              onPrev: () => _shiftMonth(-1),
              onNext: () => _shiftMonth(1),
            ),
            _CalendarGrid(cells: cells),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                children: [
                  _ScheduleHeader(label: dateLabel, count: hasActivitiesOnDay ? 3 : 0),
                  const SizedBox(height: 12),
                  if (hasActivitiesOnDay || showingAllDay) ...[
                    _ActivityCard(
                      iconAsset: 'assets/images/discovery/icons/calendar_2.svg',
                      iconBg: AppColors.primaryLight,
                      iconColor: AppColors.primary,
                      title: '5v5 Basketball Run',
                      time: '10:00 AM',
                      location: 'Central Park Court',
                      joined: '8/10',
                    ),
                    _ActivityCard(
                      iconAsset: 'assets/images/discovery/icons/heart.svg',
                      iconBg: AppColors.successBg,
                      iconColor: AppColors.success,
                      title: 'Morning Yoga Session',
                      time: '7:30 AM',
                      location: 'Riverside Studio',
                      joined: '5/12',
                    ),
                    _ActivityCard(
                      iconAsset: 'assets/images/discovery/icons/zap.svg',
                      iconBg: AppColors.warningBg,
                      iconColor: AppColors.warning,
                      title: 'Trail Running',
                      time: '5:00 PM',
                      location: 'Mountain Creek Trail',
                      joined: '4/8',
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No activities on this day.',
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const HomeIndicator(),
          ],
        ),
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  const _TopNav({required this.onNotificationTap});
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Calendar', style: AppTypography.titleScreen),
          Semantics(
            button: true,
            label: 'Notifications',
            child: NotificationIconButton(onTap: onNotificationTap),
          ),
        ],
      ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavBtn(icon: 'chevron-left.svg', onTap: onPrev),
          Text(
            label,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          _NavBtn(icon: 'chevron-right.svg', onTap: onNext),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.border),
          ),
          child: SizedBox(
            width: 14,
            height: 14,
            child: SvgPicture.asset(
              'assets/images/discovery/icons/$icon',
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(
                AppColors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.cells});
  final List<_DayCell> cells;

  static const _dowLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _dowLabels
                .map(
                  (l) => SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(
                        l,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          for (var r = 0; r < (cells.length / 7).ceil(); r++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: cells.skip(r * 7).take(7).toList(),
            ),
            if (r < (cells.length / 7).ceil() - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    this.faded = false,
    this.isToday = false,
    this.hasActivity = false,
    this.isSelected = false,
    this.onTap,
  });

  final int day;
  final bool faded;
  final bool isToday;
  final bool hasActivity;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final showHighlight = isSelected && !isToday;
    final textColor = faded
        ? AppColors.textSecondary.withValues(alpha: 0.35)
        : (isToday || isSelected)
            ? Colors.white
            : AppColors.textPrimary;

    return GestureDetector(
      onTap: faded ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isToday || showHighlight)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isToday ? AppColors.primary : AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              '$day',
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 14,
                fontWeight:
                    (isToday || isSelected) ? FontWeight.w700 : FontWeight.w500,
                color: isSelected && !isToday
                    ? AppColors.primaryDarker
                    : textColor,
              ),
            ),
            if (hasActivity && !isToday && !isSelected)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (count > 0)
          Text(
            '$count ${count == 1 ? 'Activity' : 'Activities'}',
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDarker,
            ),
          ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.iconAsset,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.time,
    required this.location,
    required this.joined,
  });

  final String iconAsset;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String time;
  final String location;
  final String joined;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SvgPicture.asset(
                    iconAsset,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          SizedBox(
                            width: 11,
                            height: 11,
                            child: SvgPicture.asset(
                              'assets/images/discovery/icons/clock.svg',
                              width: 11,
                              height: 11,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textSecondary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: SvgPicture.asset(
                              'assets/images/discovery/icons/map_pin.svg',
                              width: 10,
                              height: 10,
                              colorFilter: const ColorFilter.mode(
                                AppColors.textSecondary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      joined,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'joined',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
