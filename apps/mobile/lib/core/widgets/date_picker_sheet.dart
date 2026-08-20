import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Modal bottom sheet with a custom calendar picker. Returns the selected
/// date via `Navigator.pop(context, date)`, or `null` if cancelled.
class DatePickerSheet extends StatefulWidget {
  const DatePickerSheet({
    super.key,
    this.initialDate,
    this.minDate,
    this.maxDate,
  });

  final DateTime? initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;

  @override
  State<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<DatePickerSheet> {
  late DateTime _focused;
  late DateTime _selected;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = widget.initialDate ?? now;
    _focused = DateTime(_selected.year, _selected.month);
  }

  bool _inRange(DateTime d) {
    if (widget.minDate != null && d.isBefore(_dateOnly(widget.minDate!))) {
      return false;
    }
    if (widget.maxDate != null && d.isAfter(_dateOnly(widget.maxDate!))) {
      return false;
    }
    return true;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _shiftMonth(int delta) {
    setState(() {
      _focused = DateTime(_focused.year, _focused.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_focused.year, _focused.month, 1);
    final daysInMonth = DateTime(_focused.year, _focused.month + 1, 0).day;
    // Leading offset: weekday of day 1 (Mon=1..Sun=7) → grid index 0..6
    final leading = firstDayOfMonth.weekday % 7;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Month nav row
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_months[_focused.month - 1]} ${_focused.year}',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                _navBtn(Icons.chevron_left, () => _shiftMonth(-1)),
                const SizedBox(width: 8),
                _navBtn(Icons.chevron_right, () => _shiftMonth(1)),
              ],
            ),
            const SizedBox(height: 16),
            // Weekday labels
            Row(
              children: _weekDays
                  .map(
                    (w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Day grid
            ...List.generate(6, (row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: List.generate(7, (col) {
                    final index = row * 7 + col;
                    final dayNum = index - leading + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 40));
                    }
                    final date = DateTime(
                      _focused.year,
                      _focused.month,
                      dayNum,
                    );
                    final isSel = _dateOnly(date) == _dateOnly(_selected);
                    final isToday =
                        _dateOnly(date) == _dateOnly(DateTime.now());
                    final inRange = _inRange(date);
                    return Expanded(
                      child: _DayCell(
                        day: dayNum,
                        isSelected: isSel,
                        isToday: isToday && !isSel,
                        enabled: inRange,
                        onTap: inRange
                            ? () => setState(() => _selected = date)
                            : null,
                      ),
                    );
                  }),
                ),
              );
            }),
            const SizedBox(height: 20),
            // Confirm row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(_selected),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Text(
                          'Select Date',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.enabled,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Colors.white
        : (enabled ? AppColors.textPrimary : AppColors.textTertiary);
    final bg = isSelected
        ? AppColors.primary
        : (isToday ? AppColors.primaryLight : Colors.transparent);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: isSelected || isToday
                ? FontWeight.w700
                : FontWeight.w500,
            color: color,
          ),
        ),
      ),
    );
  }
}
