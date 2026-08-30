import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_tappable.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

enum _SkillLevel { any, beginner, intermediate, advanced }

extension _SkillLevelLabel on _SkillLevel {
  String get label {
    switch (this) {
      case _SkillLevel.any:
        return 'Any';
      case _SkillLevel.beginner:
        return 'Beginner';
      case _SkillLevel.intermediate:
        return 'Intermediate';
      case _SkillLevel.advanced:
        return 'Advanced';
    }
  }
}

enum _DatePreset { today, tomorrow, thisWeekend, thisWeek, custom }

extension _DatePresetLabel on _DatePreset {
  String get label {
    switch (this) {
      case _DatePreset.today:
        return 'Today';
      case _DatePreset.tomorrow:
        return 'Tomorrow';
      case _DatePreset.thisWeekend:
        return 'This Weekend';
      case _DatePreset.thisWeek:
        return 'This Week';
      case _DatePreset.custom:
        return 'Pick dates';
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  static const _sports = [
    'Basketball',
    'Tennis',
    'Soccer',
    'Running',
    'Swimming',
    'Cycling',
    'Volleyball',
    'Badminton',
    'Fitness',
    'Golf',
  ];

  static const _priceModes = ['Free', 'Paid', 'Both'];

  // sport index → skill level chosen for that sport (defaults to Any when first selected)
  final Map<int, _SkillLevel> _sportSkills = {0: _SkillLevel.any};

  double _distance = 5;
  int _priceMode = 2;
  _DatePreset? _datePreset = _DatePreset.today;
  DateTimeRange? _customRange;

  Set<int> get _selectedSports => _sportSkills.keys.toSet();

  void _reset() {
    setState(() {
      _sportSkills
        ..clear()
        ..addAll({0: _SkillLevel.any});
      _distance = 5;
      _priceMode = 2;
      _datePreset = null;
      _customRange = null;
    });
  }

  void _toggleSport(int i) {
    setState(() {
      if (_sportSkills.containsKey(i)) {
        _sportSkills.remove(i);
      } else {
        _sportSkills[i] = _SkillLevel.any;
      }
    });
  }

  void _setSkill(int sportIndex, _SkillLevel level) {
    setState(() => _sportSkills[sportIndex] = level);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _customRange ??
          DateTimeRange(start: now, end: now.add(const Duration(days: 3))),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.textOnPrimary,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _datePreset = _DatePreset.custom;
      });
    }
  }

  String get _distanceLabel => 'Within ${_distance.round()} km';
  String get _priceLabel => _priceModes[_priceMode];

  String get _dateLabel {
    if (_datePreset == null) return 'Any time';
    if (_datePreset == _DatePreset.custom && _customRange != null) {
      final fmt = DateFormat('d MMM');
      return '${fmt.format(_customRange!.start)} – ${fmt.format(_customRange!.end)}';
    }
    return _datePreset!.label;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedSports;

    return AppScaffold.sheet(
      title: 'Filters',
      trailingAction: 'Reset',
      onTrailingAction: _reset,
      showHomeIndicator: false,
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x3,
                AppSpacing.x5,
                AppSpacing.x4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alert banner when no sport selected
                  if (selected.isEmpty) ...[
                    _NoBannerHint(),
                    const SizedBox(height: AppSpacing.x4),
                  ],

                  // Sports + per-sport skill level
                  _SectionCard(
                    header: _SectionHeader(
                      title: 'Your sports',
                      trailing: selected.isNotEmpty
                          ? Text(
                              '${selected.length} selected',
                              style: AppTypography.caption(context).copyWith(
                                color: context.colors.primaryOnSurface,
                              ),
                            )
                          : null,
                    ),
                    child: _SportsWithSkills(
                      sports: _sports,
                      sportSkills: _sportSkills,
                      onToggleSport: _toggleSport,
                      onSetSkill: _setSkill,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Date
                  _SectionCard(
                    header: const _SectionHeader(title: 'When'),
                    child: _DatePresetGrid(
                      selected: _datePreset,
                      customRange: _customRange,
                      onSelect: (preset) {
                        if (preset == _DatePreset.custom) {
                          _pickCustomRange();
                        } else {
                          setState(() {
                            _datePreset =
                                _datePreset == preset ? null : preset;
                            _customRange = null;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Distance
                  _SectionCard(
                    header: _SectionHeader(
                      title: 'Distance',
                      trailing: _DistancePill(km: _distance.round()),
                    ),
                    child: _DistanceSlider(
                      distance: _distance,
                      onChanged: (v) => setState(() => _distance = v),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Price
                  _SectionCard(
                    header: const _SectionHeader(title: 'Price preference'),
                    child: _PriceToggle(
                      modes: _priceModes,
                      selected: _priceMode,
                      onChanged: (i) => setState(() => _priceMode = i),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                ],
              ),
            ),
          ),

          // Pinned CTA
          _ApplyBar(
            distanceLabel: _distanceLabel,
            priceLabel: _priceLabel,
            dateLabel: _dateLabel,
            onApply: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

// ─── Sports + inline skill level ─────────────────────────────────────────────

class _SportsWithSkills extends StatelessWidget {
  const _SportsWithSkills({
    required this.sports,
    required this.sportSkills,
    required this.onToggleSport,
    required this.onSetSkill,
  });

  final List<String> sports;
  final Map<int, _SkillLevel> sportSkills;
  final ValueChanged<int> onToggleSport;
  final void Function(int sportIndex, _SkillLevel level) onSetSkill;

  @override
  Widget build(BuildContext context) {
    // Build sorted list of selected sport indices in insertion order
    final selectedIndices = sportSkills.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sport pills
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: List.generate(
            sports.length,
            (i) => _SportPill(
              label: sports[i],
              selected: sportSkills.containsKey(i),
              onTap: () => onToggleSport(i),
            ),
          ),
        ),

        // Per-sport skill rows — animate in/out as sports are selected
        if (selectedIndices.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x4),
          const _SkillDivider(),
          const SizedBox(height: AppSpacing.x3),
          ...selectedIndices.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                child: _SportSkillRow(
                  sportName: sports[i],
                  current: sportSkills[i] ?? _SkillLevel.any,
                  onChanged: (level) => onSetSkill(i, level),
                ),
              )),
        ],
      ],
    );
  }
}

class _SkillDivider extends StatelessWidget {
  const _SkillDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(height: 1, color: context.colors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
          child: Text(
            'Skill level per sport',
            style: AppTypography.metaSub(context).copyWith(fontSize: 11),
          ),
        ),
        Expanded(child: Divider(height: 1, color: context.colors.border)),
      ],
    );
  }
}

class _SportSkillRow extends StatelessWidget {
  const _SportSkillRow({
    required this.sportName,
    required this.current,
    required this.onChanged,
  });

  final String sportName;
  final _SkillLevel current;
  final ValueChanged<_SkillLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sportName, style: AppTypography.labelField(context)),
        const SizedBox(height: AppSpacing.x2),
        // Segmented pill row — Any / Beginner / Intermediate / Advanced
        _SkillSegment(current: current, onChanged: onChanged),
      ],
    );
  }
}

class _SkillSegment extends StatelessWidget {
  const _SkillSegment({required this.current, required this.onChanged});
  final _SkillLevel current;
  final ValueChanged<_SkillLevel> onChanged;

  static const _levels = _SkillLevel.values;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: _levels.map((level) {
          final isSelected = level == current;
          return Expanded(
            child: AppTappable(
              semanticLabel: level.label,
              onTap: () => onChanged(level),
              feedback: AppTapFeedback.scale,
              minSize: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  level.label,
                  style: AppTypography.metaSub(context).copyWith(
                    fontSize: 11,
                    color: isSelected
                        ? AppColors.textOnPrimary
                        : context.colors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Section card wrapper ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.header, required this.child});
  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: AppSpacing.x3),
          child,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.titleMedium(context))),
        ?trailing,
      ],
    );
  }
}

// ─── Alert banner ─────────────────────────────────────────────────────────────

class _NoBannerHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: context.colors.primaryOnSurface.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.colors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppIcon(
              AppIcons.bell,
              size: AppIconSize.md,
              color: context.colors.primaryOnSurface,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No sports selected',
                    style: AppTypography.labelField(context)),
                const SizedBox(height: 2),
                Text(
                  'Pick the sports you play to discover games',
                  style: AppTypography.metaSub(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sport pill ───────────────────────────────────────────────────────────────

class _SportPill extends StatelessWidget {
  const _SportPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2 + 2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primarySoft
              : context.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? context.colors.primaryOnSurface
                : context.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(
                Icons.check_rounded,
                size: 13,
                color: context.colors.primaryOnSurface,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.chipLabel(context).copyWith(
                fontSize: 13,
                color: selected
                    ? context.colors.primaryOnSurface
                    : context.colors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date preset grid ─────────────────────────────────────────────────────────

class _DatePresetGrid extends StatelessWidget {
  const _DatePresetGrid({
    required this.selected,
    required this.customRange,
    required this.onSelect,
  });
  final _DatePreset? selected;
  final DateTimeRange? customRange;
  final ValueChanged<_DatePreset> onSelect;

  static const _presets = _DatePreset.values;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: _presets.map((preset) {
        final isSelected = selected == preset;
        final label =
            (preset == _DatePreset.custom && isSelected && customRange != null)
                ? _formatRange(customRange!)
                : preset.label;

        return AppTappable(
          semanticLabel: preset.label,
          onTap: () => onSelect(preset),
          feedback: AppTapFeedback.scale,
          minSize: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x2 + 2,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.primarySoft
                  : context.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isSelected
                    ? context.colors.primaryOnSurface
                    : context.colors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (preset == _DatePreset.custom)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.calendar_month_rounded, size: 13,
                        color: context.colors.primaryOnSurface),
                  ),
                Text(
                  label,
                  style: AppTypography.chipLabel(context).copyWith(
                    fontSize: 13,
                    color: isSelected
                        ? context.colors.primaryOnSurface
                        : context.colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatRange(DateTimeRange range) {
    final fmt = DateFormat('d MMM');
    return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }
}

// ─── Distance pill label ──────────────────────────────────────────────────────

class _DistancePill extends StatelessWidget {
  const _DistancePill({required this.km});
  final int km;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'Within $km km',
        style: AppTypography.chipLabel(context).copyWith(
          color: AppColors.textOnPrimary,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─── Distance slider ──────────────────────────────────────────────────────────

class _DistanceSlider extends StatelessWidget {
  const _DistanceSlider({required this.distance, required this.onChanged});
  final double distance;
  final ValueChanged<double> onChanged;

  static const double _min = 1;
  static const double _max = 30;
  static const _ticks = ['1 km', '10 km', '20 km', '30 km'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How far will you go?', style: AppTypography.metaSub(context)),
        const SizedBox(height: AppSpacing.x1),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: context.colors.border,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: distance.clamp(_min, _max),
            min: _min,
            max: _max,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _ticks
                .map((t) => Text(t, style: AppTypography.metaSub(context)))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Price toggle ─────────────────────────────────────────────────────────────

class _PriceToggle extends StatelessWidget {
  const _PriceToggle({
    required this.modes,
    required this.selected,
    required this.onChanged,
  });
  final List<String> modes;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: List.generate(modes.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: AppTappable(
              semanticLabel: modes[i],
              onTap: () => onChanged(i),
              feedback: AppTapFeedback.scale,
              minSize: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Text(
                  modes[i],
                  style: AppTypography.labelField(context).copyWith(
                    color: isSelected
                        ? AppColors.textOnPrimary
                        : context.colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Apply bar ────────────────────────────────────────────────────────────────

class _ApplyBar extends StatelessWidget {
  const _ApplyBar({
    required this.distanceLabel,
    required this.priceLabel,
    required this.dateLabel,
    required this.onApply,
  });
  final String distanceLabel;
  final String priceLabel;
  final String dateLabel;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x5,
        AppSpacing.x3,
        AppSpacing.x5,
        AppSpacing.x5,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: AppShadows.bottomBar,
      ),
      child: AppTappable(
        semanticLabel: 'Show all activities',
        onTap: onApply,
        feedback: AppTapFeedback.scale,
        minSize: 0,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.glowPrimary,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Show all activities', style: AppTypography.buttonPrimary),
              const SizedBox(height: 2),
              Text(
                '$dateLabel · $distanceLabel · $priceLabel',
                style: AppTypography.metaSub(context).copyWith(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.75),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
