import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/status_bar_mock.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';

const _primaryDarker = Color(0xFF145AC8);

class GetToKnow2Screen extends StatefulWidget {
  const GetToKnow2Screen({super.key});

  @override
  State<GetToKnow2Screen> createState() => _GetToKnow2ScreenState();
}

class _GetToKnow2ScreenState extends State<GetToKnow2Screen> {
  int _weight = 73;
  int _day = 29;
  int _month = 3;
  int _year = 1996;

  static const _months = [
    'Jan', 'Feb', 'March', 'April', 'May', 'June',
    'July', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Give us some final details',
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will help us calculate matching distance, calorie metrics and sports team brackets.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _LabeledField(
                      label: 'Height',
                      child: _ReadOnlyInput(
                        icon: Icons.straighten,
                        value: '183 cm',
                      ),
                    ),
                    const SizedBox(height: 24),
                    _WeightCard(
                      weight: _weight,
                      onMinus: () => setState(() => _weight--),
                      onPlus: () => setState(() => _weight++),
                    ),
                    const SizedBox(height: 24),
                    _LabeledField(
                      label: 'Date of Birth',
                      child: _ReadOnlyInput(
                        icon: Icons.calendar_today_outlined,
                        value: '$_day ${_months[_month - 1]} $_year',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DateWheelPicker(
                      day: _day,
                      month: _month,
                      year: _year,
                      onChanged: (d, m, y) => setState(() {
                        _day = d;
                        _month = m;
                        _year = y;
                      }),
                    ),
                    const SizedBox(height: 16),
                    PrimaryPillButton(
                      label: 'Next',
                      onPressed: () => context.push('/preferences'),
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: Icon(Icons.arrow_back, size: 24, color: AppColors.textPrimary),
              ),
            ),
          ),
          Expanded(
            child: Text(
              "LET'S GET TO KNOW YOU",
              textAlign: TextAlign.center,
              style: AppTypography.inputLabelSmall.copyWith(
                color: _primaryDarker,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.inputLabel),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ReadOnlyInput extends StatelessWidget {
  const _ReadOnlyInput({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.weight,
    required this.onMinus,
    required this.onPlus,
  });
  final int weight;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Weight',
                style: AppTypography.inputLabel,
              ),
              Text(
                'kg',
                style: AppTypography.inputLabel.copyWith(
                  color: _primaryDarker,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Decrease weight',
                child: GestureDetector(
                  onTap: onMinus,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                    ),
                    child: const Icon(Icons.remove_circle_outline,
                        size: 32, color: AppColors.textPrimary),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final w in [weight - 2, weight - 1, weight, weight + 1, weight + 2])
                      Expanded(
                        child: Center(
                          child: Text(
                            '$w',
                            style: TextStyle(
                              fontWeight: w == weight
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              fontSize: w == weight ? 28 : 18,
                              color: w == weight
                                  ? _primaryDarker
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Increase weight',
                child: GestureDetector(
                  onTap: onPlus,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                    ),
                    child: const Icon(Icons.add_circle_outline,
                        size: 32, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateWheelPicker extends StatelessWidget {
  const _DateWheelPicker({
    required this.day,
    required this.month,
    required this.year,
    required this.onChanged,
  });
  final int day;
  final int month;
  final int year;
  final void Function(int d, int m, int y) onChanged;

  static const _monthsFull = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _col(1, 31, day, (v) => onChanged(v, month, year))),
          Expanded(
            child: _col(1, 12, month, (v) => onChanged(day, v, year),
                labels: _monthsFull),
          ),
          Expanded(child: _col(1980, 2010, year, (v) => onChanged(day, month, v))),
        ],
      ),
    );
  }

  Widget _col(int min, int max, int value, ValueChanged<int> onChange,
      {List<String>? labels}) {
    return SizedBox(
      height: 130,
      child: ListWheelScrollView.useDelegate(
        itemExtent: 26,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.003,
        onSelectedItemChanged: (i) => onChange(min + i),
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, i) {
            if (i < 0 || i > max - min) return null;
            final isSelected = (min + i) == value;
            return Center(
              child: Text(
                labels != null ? labels[i] : '${min + i}',
                style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: isSelected ? 18 : 14,
                  color: isSelected ? _primaryDarker : AppColors.textSecondary,
                ),
              ),
            );
          },
          childCount: max - min + 1,
        ),
      ),
    );
  }
}