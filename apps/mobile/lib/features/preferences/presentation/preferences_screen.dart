import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';

enum SkillLevel { beginner, intermediate, advanced }

enum PricePreference { free, paid, both }

extension PricePreferenceX on PricePreference {
  String get label => switch (this) {
        PricePreference.free => 'Free',
        PricePreference.paid => 'Paid',
        PricePreference.both => 'Both',
      };

  IconData get icon => switch (this) {
        PricePreference.free => Icons.local_offer_outlined,
        PricePreference.paid => Icons.payments_outlined,
        PricePreference.both => Icons.all_inclusive,
      };
}

extension SkillLevelX on SkillLevel {
  String get label => switch (this) {
        SkillLevel.beginner => 'Beginner',
        SkillLevel.intermediate => 'Intermediate',
        SkillLevel.advanced => 'Advanced',
      };

  String get short => switch (this) {
        SkillLevel.beginner => 'Bgnr',
        SkillLevel.intermediate => 'Intm',
        SkillLevel.advanced => 'Adv',
      };
}

class _SportOption {
  const _SportOption({
    required this.name,
    required this.icon,
  });

  final String name;
  final IconData icon;
}

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  static const List<_SportOption> _sports = [
    _SportOption(name: 'Basketball', icon: Icons.sports_basketball),
    _SportOption(name: 'Tennis', icon: Icons.sports_tennis),
    _SportOption(name: 'Soccer', icon: Icons.sports_soccer),
    _SportOption(name: 'Running', icon: Icons.directions_run),
    _SportOption(name: 'Swimming', icon: Icons.pool),
    _SportOption(name: 'Cycling', icon: Icons.directions_bike),
    _SportOption(name: 'Volleyball', icon: Icons.sports_volleyball),
    _SportOption(name: 'Badminton', icon: Icons.sports_handball),
    _SportOption(name: 'Fitness', icon: Icons.fitness_center),
    _SportOption(name: 'Golf', icon: Icons.sports_golf),
  ];

  final Map<String, SkillLevel> _selected = <String, SkillLevel>{};
  double _distanceKm = 5;
  PricePreference _price = PricePreference.both;

  static const double _minDistance = 1;
  static const double _maxDistance = 30;

  // ── Read initial values from providers on first build ─────────────────────
  bool _initialised = false;
  void _initFromProviders() {
    if (_initialised) return;
    _initialised = true;
    final prefs = ref.read(sportPreferencesProvider);
    for (final e in prefs.entries) {
      final level = SkillLevel.values.firstWhere(
        (l) => l.label == e.value,
        orElse: () => SkillLevel.intermediate,
      );
      _selected[e.key] = level;
    }
    _distanceKm = ref.read(distanceFilterProvider);
    final priceStr = ref.read(priceFilterProvider);
    _price = PricePreference.values.firstWhere(
      (p) => p.label == priceStr,
      orElse: () => PricePreference.both,
    );
  }

  // ── Persist to providers whenever user applies ────────────────────────────
  void _applyToProviders() {
    ref.read(sportPreferencesProvider.notifier).setAll(
          _selected.map((k, v) => MapEntry(k, v.label)),
        );
    ref.read(distanceFilterProvider.notifier).state = _distanceKm;
    ref.read(priceFilterProvider.notifier).state = _price.label;
  }

  int get _selectedCount => _selected.length;

  Map<SkillLevel, int> get _distribution {
    final m = <SkillLevel, int>{
      for (final s in SkillLevel.values) s: 0,
    };
    for (final l in _selected.values) {
      m[l] = (m[l] ?? 0) + 1;
    }
    return m;
  }

  SkillLevel? get _dominantSkill {
    if (_selected.isEmpty) return null;
    final dist = _distribution;
    SkillLevel? best;
    var bestCount = 0;
    for (final entry in dist.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  String get _filterSummary {
    final parts = <String>[];
    if (_selectedCount > 0) {
      parts.add(
        '$_selectedCount ${_selectedCount == 1 ? 'sport' : 'sports'}',
      );
    }
    parts.add('Within ${_distanceKm.toStringAsFixed(0)} km');
    parts.add(_price.label);
    return parts.join(' · ');
  }

  Future<void> _onTapSport(_SportOption option) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _SkillSheet(
        sportName: option.name,
        sportIcon: option.icon,
        current: _selected[option.name],
      ),
    );
    if (!mounted) return;
    if (result is SkillLevel) {
      setState(() => _selected[option.name] = result);
    } else if (result == _kClearAction) {
      setState(() => _selected.remove(option.name));
    }
  }

  void _reset() => setState(() {
        _selected.clear();
        _distanceKm = 5;
        _price = PricePreference.both;
      });

  @override
  Widget build(BuildContext context) {
    _initFromProviders();
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroSummary(
                      count: _selectedCount,
                      dominant: _dominantSkill,
                      distribution: _distribution,
                      onReset: _selectedCount == 0 ? null : _reset,
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Your sports',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SportGrid(
                      sports: _sports,
                      selected: _selected,
                      onTap: _onTapSport,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(
                      label: 'Distance',
                      trailing: Text(
                        'Within ${_distanceKm.toStringAsFixed(0)} km',
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DistanceCard(
                      value: _distanceKm,
                      min: _minDistance,
                      max: _maxDistance,
                      onChanged: (v) => setState(() => _distanceKm = v),
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel(label: 'Price preference'),
                    const SizedBox(height: 12),
                    _PriceCard(
                      value: _price,
                      onChanged: (v) => setState(() => _price = v),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryPillButton(
                    label: _selectedCount == 0
                        ? 'Show all activities'
                        : 'Apply Filters',
                    onPressed: () {
                      _applyToProviders();
                      context.go('/discovery');
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _filterSummary,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Filters',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({
    required this.count,
    required this.dominant,
    required this.distribution,
    required this.onReset,
  });

  final int count;
  final SkillLevel? dominant;
  final Map<SkillLevel, int> distribution;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final subtitle = count == 0
        ? 'Pick the sports you play'
        : 'Mostly ${dominant?.label ?? '—'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F0FF), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryLight, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bolt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count == 0
                          ? 'No sports selected'
                          : '$count ${count == 1 ? 'sport' : 'sports'} selected',
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontStyle: count == 0
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (onReset != null)
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Reset',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (count > 0) ...[
            const SizedBox(height: 16),
            _SkillDistributionBars(dist: distribution),
          ],
        ],
      ),
    );
  }
}

class _SkillDistributionBars extends StatelessWidget {
  const _SkillDistributionBars({required this.dist});

  final Map<SkillLevel, int> dist;

  @override
  Widget build(BuildContext context) {
    final total = dist.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final s in SkillLevel.values)
              Expanded(
                child: Text(
                  s.label,
                  textAlign: TextAlign.left,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final s in SkillLevel.values) ...[
              Expanded(
                flex: (dist[s] ?? 0).clamp(0, 1000),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: s.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (s != SkillLevel.advanced) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }
}

extension on SkillLevel {
  Color get color => switch (this) {
        SkillLevel.beginner => const Color(0xFF22C55E),
        SkillLevel.intermediate => AppColors.primary,
        SkillLevel.advanced => const Color(0xFFF59E0B),
      };
}

class _SportGrid extends StatelessWidget {
  const _SportGrid({
    required this.sports,
    required this.selected,
    required this.onTap,
  });

  final List<_SportOption> sports;
  final Map<String, SkillLevel> selected;
  final void Function(_SportOption) onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: sports.length,
      itemBuilder: (_, i) {
        final opt = sports[i];
        return _SportCard(
          option: opt,
          level: selected[opt.name],
          onTap: () => onTap(opt),
        );
      },
    );
  }
}

class _SportCard extends StatelessWidget {
  const _SportCard({
    required this.option,
    required this.level,
    required this.onTap,
  });

  final _SportOption option;
  final SkillLevel? level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = level != null;
    return Semantics(
      button: true,
      label: selected
          ? '${option.name}, ${level!.label}'
          : '${option.name}, not selected',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: AppColors.shadowCard,
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.icon,
                  size: 22,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                option.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primaryDarker : AppColors.textLabel,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 16,
                child: selected
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            level!.short,
                            style: AppTypography.bodyMedium.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.expand_more,
                            size: 12,
                            color: AppColors.primary,
                          ),
                        ],
                      )
                    : const Icon(
                        Icons.add,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Object _kClearAction = Object();

class _SkillSheet extends StatefulWidget {
  const _SkillSheet({
    required this.sportName,
    required this.sportIcon,
    required this.current,
  });

  final String sportName;
  final IconData sportIcon;
  final SkillLevel? current;

  @override
  State<_SkillSheet> createState() => _SkillSheetState();
}

class _SkillSheetState extends State<_SkillSheet> {
  late SkillLevel _draft = widget.current ?? SkillLevel.beginner;

  void _save() => Navigator.of(context).pop(_draft);

  void _remove() => Navigator.of(context).pop(_kClearAction);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.sportIcon,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.sportName,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pick your skill level',
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SegmentedSkill(
              value: _draft,
              onChanged: (v) => setState(() => _draft = v),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (widget.current != null) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: _remove,
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
                            'Remove',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _save,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Text(
                          'Done',
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
}

class _SegmentedSkill extends StatelessWidget {
  const _SegmentedSkill({required this.value, required this.onChanged});

  final SkillLevel value;
  final ValueChanged<SkillLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final s in SkillLevel.values)
            Expanded(
              child: _SegmentButton(
                label: s.label,
                selected: s == value,
                onTap: () => onChanged(s),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textLabel,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  const _DistanceCard({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final divisions = (max - min).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.near_me_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'How far will you go?',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 9,
                elevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${min.toStringAsFixed(0)} km',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${max.toStringAsFixed(0)} km',
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
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

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.value, required this.onChanged});

  final PricePreference value;
  final ValueChanged<PricePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final p in PricePreference.values) ...[
            Expanded(
              child: _PriceChip(
                option: p,
                selected: p == value,
                onTap: () => onChanged(p),
              ),
            ),
            if (p != PricePreference.both) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PricePreference option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: option.label,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 20,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
              const SizedBox(height: 6),
              Text(
                option.label,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

