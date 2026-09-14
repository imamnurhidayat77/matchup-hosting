import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/profile_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../tour/presentation/tour_controller.dart';
import '../../tour/presentation/tour_steps.dart';
import 'get_to_know_1_screen.dart' show OnboardingProgressHeader;

/// Final onboarding step — collects the physical details that live on
/// [UserModel] (height, weight, date of birth) and persists them through
/// `UserRepository.updateProfile` before entering the app.
class GetToKnow3Screen extends ConsumerStatefulWidget {
  const GetToKnow3Screen({super.key});

  @override
  ConsumerState<GetToKnow3Screen> createState() => _GetToKnow3ScreenState();
}

class _GetToKnow3ScreenState extends ConsumerState<GetToKnow3Screen> {
  final _heightController = TextEditingController(text: '183');

  int _weightKg = 73;

  // Date of birth, split so each wheel can be driven independently.
  int _day = 29;
  int _month = 3;
  int _year = 1996;

  bool _saving = false;

  static const _minWeight = 30;
  static const _maxWeight = 200;
  static const _minYear = 1940;

  int get _maxYear => DateTime.now().year - 13; // 13+ to hold an account

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  /// Clamps the day when the selected month/year can't hold it (e.g. 31 Feb).
  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;

  void _normaliseDay() {
    if (_day > _daysInMonth) _day = _daysInMonth;
  }

  DateTime get _dateOfBirth => DateTime(_year, _month, _day);

  Future<void> _onNext() async {
    final heightCm = int.tryParse(_heightController.text.trim());
    if (heightCm == null || heightCm < 100 || heightCm > 250) {
      AppSnackbar.show(
        context,
        message: 'Enter a height between 100 and 250 cm.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile(
        heightCm: heightCm,
        weightKg: _weightKg,
        dateOfBirth: _dateOfBirth,
      );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      // Arm the first-run tour. Deferred to the post-frame callback of
      // the *next* frame so Discovery's anchors (swipeDeck, actionRow,
      // tab bar) are mounted and measurable before the overlay tries
      // to spotlight them — without this the holeRect comes back null
      // and the overlay renders off-screen / clipped.
      context.go('/discovery');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(tourControllerProvider.notifier)
            .maybeStart(kFirstRunTourId, kFirstRunTour);
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Could not save your details. Please try again.',
        variant: AppSnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AppScaffold(
      showHomeIndicator: true,
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          OnboardingProgressHeader(step: 3, total: 3),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x4,
                AppSpacing.x5,
                AppSpacing.x5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Give us some final details',
                    style: AppTypography.titleScreen(context).copyWith(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'Tell us more about you.',
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x5),

                  // ── Height ─────────────────────────────────────────
                  Text('Height', style: _fieldLabel(context)),
                  const SizedBox(height: AppSpacing.x2),
                  _HeightField(controller: _heightController),
                  const SizedBox(height: AppSpacing.x4),

                  // ── Weight ─────────────────────────────────────────
                  _WeightCard(
                    value: _weightKg,
                    min: _minWeight,
                    max: _maxWeight,
                    onChanged: (v) => setState(() => _weightKg = v),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // ── Date of birth ──────────────────────────────────
                  Text('Date of Birth', style: _fieldLabel(context)),
                  const SizedBox(height: AppSpacing.x2),
                  _DobField(date: _dateOfBirth),
                  const SizedBox(height: AppSpacing.x3),
                  _DobPicker(
                    day: _day,
                    month: _month,
                    year: _year,
                    daysInMonth: _daysInMonth,
                    minYear: _minYear,
                    maxYear: _maxYear,
                    onDayChanged: (v) => setState(() => _day = v),
                    onMonthChanged: (v) => setState(() {
                      _month = v;
                      _normaliseDay();
                    }),
                    onYearChanged: (v) => setState(() {
                      _year = v;
                      _normaliseDay();
                    }),
                  ),
                ],
              ),
            ),
          ),

          // ── Next ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.colors.border)),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x4,
              AppSpacing.x5,
              bottomPad + AppSpacing.x3,
            ),
            child: PressableScale(
              onTap: _saving ? null : _onNext,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: _saving
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: _saving ? null : AppShadows.glowPrimary,
                ),
                alignment: Alignment.center,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.textOnPrimary,
                          ),
                        ),
                      )
                    : Text(
                        'Complete Profile',
                        style: AppTypography.buttonPrimary,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _fieldLabel(BuildContext context) =>
    AppTypography.labelField(context).copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w800,
    );

const Color _fieldBorder = Color(0xFFE5E7EB);
const Color _pickerFill = Color(0xFFF9FAFB);

// ─── Height field ─────────────────────────────────────────────────────────────

class _HeightField extends StatelessWidget {
  const _HeightField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      cursorColor: AppColors.primary,
      style: AppTypography.bodyReading(context).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.x4),
          child: Icon(
            Icons.straighten_rounded,
            size: 20,
            color: context.colors.textSecondary,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 52),
        suffixText: 'cm',
        suffixStyle: AppTypography.bodyReading(context).copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.colors.textPrimary,
        ),
        filled: true,
        fillColor: AppColors.textOnPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

// ─── Weight card ──────────────────────────────────────────────────────────────

/// Horizontal number strip with −/+ steppers. Shows two neighbours either
/// side of the selection, greyed out, with the current value highlighted.
class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Select Weight', style: _fieldLabel(context)),
              const Spacer(),
              Text(
                'kg',
                style: _fieldLabel(context).copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                enabled: value > min,
                emphasised: false,
                onTap: () => onChanged(value - 1),
                semanticLabel: 'Decrease weight',
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var offset = -2; offset <= 2; offset++)
                      _WeightTick(
                        value: value + offset,
                        selected: offset == 0,
                        visible: value + offset >= min && value + offset <= max,
                      ),
                  ],
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                enabled: value < max,
                emphasised: true,
                onTap: () => onChanged(value + 1),
                semanticLabel: 'Increase weight',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightTick extends StatelessWidget {
  const _WeightTick({
    required this.value,
    required this.selected,
    required this.visible,
  });

  final int value;
  final bool selected;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(width: 32);

    if (selected) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x2,
        ),
        decoration: BoxDecoration(
          color: context.colors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          '$value',
          style: AppTypography.titleScreen(context).copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: context.colors.primaryOnSurface,
          ),
        ),
      );
    }

    return Text(
      '$value',
      style: AppTypography.bodyReading(context).copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: context.colors.textTertiary,
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.emphasised,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final bool enabled;

  /// The `+` button carries a primary-tinted border in the design; `−` is
  /// plain grey.
  final bool emphasised;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint = emphasised
        ? context.colors.primaryOnSurface
        : context.colors.textSecondary;
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: enabled,
      child: PressableScale(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: emphasised
                    ? context.colors.primaryOnSurface
                    : _fieldBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: tint),
          ),
        ),
      ),
    );
  }
}

// ─── Date of birth ────────────────────────────────────────────────────────────

class _DobField extends StatelessWidget {
  const _DobField({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.x3),
          Text(
            DateFormat('d MMMM yyyy').format(date),
            style: AppTypography.bodyReading(context).copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three synced wheels (day · month · year) with the centre row highlighted.
class _DobPicker extends StatelessWidget {
  const _DobPicker({
    required this.day,
    required this.month,
    required this.year,
    required this.daysInMonth,
    required this.minYear,
    required this.maxYear,
    required this.onDayChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  final int day;
  final int month;
  final int year;
  final int daysInMonth;
  final int minYear;
  final int maxYear;
  final ValueChanged<int> onDayChanged;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  static const double _rowHeight = 36;
  static const double _height = _rowHeight * 5;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: _pickerFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _fieldBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Centre selection band
          Positioned(
            top: _rowHeight * 2,
            left: 0,
            right: 0,
            height: _rowHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: _fieldBorder),
                ),
              ),
            ),
          ),
          // Wheels
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: _Wheel(
                    key: ValueKey('day-$daysInMonth'),
                    itemCount: daysInMonth,
                    selectedIndex: day - 1,
                    labelAt: (i) => '${i + 1}',
                    onSelected: (i) => onDayChanged(i + 1),
                    semanticLabel: 'Day',
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _Wheel(
                    key: const ValueKey('month'),
                    itemCount: 12,
                    selectedIndex: month - 1,
                    labelAt: (i) =>
                        DateFormat('MMMM').format(DateTime(2000, i + 1)),
                    onSelected: (i) => onMonthChanged(i + 1),
                    semanticLabel: 'Month',
                  ),
                ),
                Expanded(
                  child: _Wheel(
                    key: const ValueKey('year'),
                    itemCount: maxYear - minYear + 1,
                    selectedIndex: year - minYear,
                    labelAt: (i) => '${minYear + i}',
                    onSelected: (i) => onYearChanged(minYear + i),
                    semanticLabel: 'Year',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Wheel extends StatefulWidget {
  const _Wheel({
    super.key,
    required this.itemCount,
    required this.selectedIndex,
    required this.labelAt,
    required this.onSelected,
    required this.semanticLabel,
  });

  final int itemCount;
  final int selectedIndex;
  final String Function(int index) labelAt;
  final ValueChanged<int> onSelected;
  final String semanticLabel;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.selectedIndex);

  @override
  void didUpdateWidget(_Wheel old) {
    super.didUpdateWidget(old);
    // Sync position when selected index changes externally (e.g. day clamped
    // after month switch). Use postFrameCallback to avoid calling jumpToItem
    // during a build/layout phase.
    if (widget.selectedIndex != _controller.selectedItem &&
        _controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToItem(
            widget.selectedIndex.clamp(0, widget.itemCount - 1),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: _DobPicker._rowHeight,
        diameterRatio: 100,
        overAndUnderCenterOpacity: 0.45,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: widget.onSelected,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.itemCount,
          builder: (context, i) {
            final selected = i == widget.selectedIndex;
            return Center(
              child: Text(
                widget.labelAt(i),
                style: AppTypography.bodyReading(context).copyWith(
                  fontSize: selected ? 19 : 16,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected
                      ? context.colors.primaryOnSurface
                      : context.colors.textTertiary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
