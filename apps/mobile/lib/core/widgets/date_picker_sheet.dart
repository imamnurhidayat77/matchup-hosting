import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/dark_colors.dart';
import 'app_tappable.dart';
import 'pressable_scale.dart';

/// Modal bottom sheet with a calendar + time picker.
///
/// Returns a [DateTime] that combines the selected date and time via
/// `Navigator.pop(context, dateTime)`, or `null` if cancelled.
///
/// The time picker renders two scrollable columns (hour / minute) in
/// 12-hour format with an AM/PM toggle — compact enough to sit in the same
/// sheet without crowding the calendar.
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

  // Time state
  late int _hour12;   // 1–12
  late int _minute;   // 0–59, shown in 5-min steps
  late bool _isPm;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _minuteStep = 5;

  @override
  void initState() {
    super.initState();
    final init = widget.initialDate ?? DateTime.now().add(const Duration(hours: 1));
    _selected = init;
    _focused = DateTime(_selected.year, _selected.month);

    // Decompose time into 12h + am/pm
    final h = init.hour;
    _isPm = h >= 12;
    _hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    // Round minute up to nearest step
    _minute = ((init.minute / _minuteStep).ceil() * _minuteStep) % 60;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  void _shiftMonth(int delta) => setState(() {
        _focused = DateTime(_focused.year, _focused.month + delta);
      });

  DateTime get _result {
    final h24 = _isPm
        ? (_hour12 == 12 ? 12 : _hour12 + 12)
        : (_hour12 == 12 ? 0 : _hour12);
    return DateTime(_selected.year, _selected.month, _selected.day, h24, _minute);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(_focused.year, _focused.month, 1);
    final daysInMonth = DateTime(_focused.year, _focused.month + 1, 0).day;
    final leading = firstDayOfMonth.weekday % 7;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x6, AppSpacing.x3, AppSpacing.x6, AppSpacing.x6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: AppRadius.pillR,
              ),
            ),

            // ── Calendar ────────────────────────────────────────────────
            // Month nav
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_months[_focused.month - 1]} ${_focused.year}',
                    style: AppTypography.titleLarge(context)
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                _navBtn(context, Icons.chevron_left, 'Previous month',
                    () => _shiftMonth(-1)),
                const SizedBox(width: 8),
                _navBtn(context, Icons.chevron_right, 'Next month',
                    () => _shiftMonth(1)),
              ],
            ),
            const SizedBox(height: 12),
            // Weekday labels
            Row(
              children: _weekDays
                  .map((w) => Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: AppTypography.bodySmall(context).copyWith(
                              color: context.colors.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
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
                    final date = DateTime(_focused.year, _focused.month, dayNum);
                    final isSel = _dateOnly(date) == _dateOnly(_selected);
                    final isToday = _dateOnly(date) == _dateOnly(DateTime.now());
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

            const SizedBox(height: AppSpacing.x4),
            Divider(height: 1, color: context.colors.border),
            const SizedBox(height: AppSpacing.x4),

            // ── Time picker ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour drum
                _TimeColumn(
                  values: List.generate(12, (i) => i + 1),
                  selected: _hour12,
                  label: (v) => v.toString().padLeft(2, '0'),
                  onChanged: (v) => setState(() => _hour12 = v),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                  child: Text(
                    ':',
                    style: AppTypography.titleSheet(context)
                        .copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                // Minute drum
                _TimeColumn(
                  values: List.generate(60 ~/ _minuteStep, (i) => i * _minuteStep),
                  selected: _minute,
                  label: (v) => v.toString().padLeft(2, '0'),
                  onChanged: (v) => setState(() => _minute = v),
                ),
                const SizedBox(width: AppSpacing.x4),
                // AM / PM toggle
                _AmPmToggle(
                  isPm: _isPm,
                  onChanged: (v) => setState(() => _isPm = v),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.x5),

            // ── Confirm row ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Cancel',
                    child: PressableScale(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: AppRadius.pillR,
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: AppTypography.bodyMedium(context).copyWith(
                              color: context.colors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Semantics(
                    button: true,
                    label: 'Confirm date and time',
                    child: PressableScale(
                      onTap: () => Navigator.of(context).pop(_result),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.pillR,
                        ),
                        child: Center(
                          child: Text(
                            'Confirm',
                            style: AppTypography.bodyMedium(context).copyWith(
                              color: AppColors.textOnPrimary,
                              fontWeight: FontWeight.w700,
                            ),
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

  Widget _navBtn(
    BuildContext context,
    IconData icon,
    String semanticLabel,
    VoidCallback onTap,
  ) {
    return AppTappable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      feedback: AppTapFeedback.scale,
      borderRadius: AppRadius.pill,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.pillR,
          border: Border.all(color: context.colors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: context.colors.textPrimary),
      ),
    );
  }
}

// ─── Time column (scrollable drum) ────────────────────────────────────────────

class _TimeColumn extends StatefulWidget {
  const _TimeColumn({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<int> values;
  final int selected;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  State<_TimeColumn> createState() => _TimeColumnState();
}

class _TimeColumnState extends State<_TimeColumn> {
  late final FixedExtentScrollController _ctrl;
  static const double _itemH = 44;
  static const int _loopFactor = 200; // large multiplier for seamless wrapping

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.values.indexOf(widget.selected);
    // Centre in the large loop so we can scroll both directions freely
    final startIndex = _loopFactor ~/ 2 * widget.values.length +
        (initialIndex < 0 ? 0 : initialIndex);
    _ctrl = FixedExtentScrollController(initialItem: startIndex);
  }

  @override
  void didUpdateWidget(_TimeColumn old) {
    super.didUpdateWidget(old);
    // If parent resets selection externally, jump the drum to match
    if (old.selected != widget.selected) {
      final idx = widget.values.indexOf(widget.selected);
      if (idx >= 0) {
        final current = _ctrl.selectedItem;
        final base = (current ~/ widget.values.length) * widget.values.length;
        _ctrl.jumpToItem(base + idx);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.values.length;
    return SizedBox(
      width: 52,
      height: _itemH * 3,
      child: ListWheelScrollView.useDelegate(
        controller: _ctrl,
        itemExtent: _itemH,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.004,
        diameterRatio: 2.2,
        onSelectedItemChanged: (i) {
          widget.onChanged(widget.values[i % count]);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            final val = widget.values[i % count];
            final isSelected = val == widget.selected;
            return Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: isSelected
                    ? AppTypography.titleSheet(context).copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      )
                    : AppTypography.bodyMedium(context).copyWith(
                        fontSize: 17,
                        color: context.colors.textTertiary,
                      ),
                child: Text(widget.label(val)),
              ),
            );
          },
          childCount: _loopFactor * count,
        ),
      ),
    );
  }
}

// ─── AM / PM toggle ───────────────────────────────────────────────────────────

class _AmPmToggle extends StatelessWidget {
  const _AmPmToggle({required this.isPm, required this.onChanged});
  final bool isPm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: 'AM',
            selected: !isPm,
            topRadius: true,
            bottomRadius: false,
            onTap: () => onChanged(false),
          ),
          Divider(height: 1, color: context.colors.border),
          _Segment(
            label: 'PM',
            selected: isPm,
            topRadius: false,
            bottomRadius: true,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.topRadius,
    required this.bottomRadius,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool topRadius;
  final bool bottomRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTappable(
      semanticLabel: label,
      onTap: onTap,
      feedback: AppTapFeedback.scale,
      minSize: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 38,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.vertical(
            top: topRadius ? const Radius.circular(AppRadius.md) : Radius.zero,
            bottom: bottomRadius
                ? const Radius.circular(AppRadius.md)
                : Radius.zero,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.chipLabel(context).copyWith(
            fontSize: 13,
            color: selected ? AppColors.textOnPrimary : context.colors.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Day cell ─────────────────────────────────────────────────────────────────

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
        ? AppColors.textOnPrimary
        : (enabled ? context.colors.textPrimary : context.colors.textTertiary);
    final bg = isSelected
        ? AppColors.primary
        : (isToday ? context.colors.primaryLight : Colors.transparent);
    final label = [
      '$day',
      if (isToday) '(today)',
      if (isSelected) '(selected)',
    ].join(' ');

    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      selected: isSelected,
      child: PressableScale(
        onTap: onTap,
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: AppTypography.labelField(context).copyWith(
              fontWeight:
                  isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
