import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pill_buttons.dart';
import 'widgets/preference_types.dart';
import 'widgets/preferences_distance_card.dart';
import 'widgets/preferences_hero_summary.dart';
import 'widgets/preferences_price_card.dart';
import 'widgets/preferences_skill_sheet.dart';
import 'widgets/preferences_sport_grid.dart';

class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  static const List<SportOption> _sports = [
    SportOption(name: 'Basketball', icon: Icons.sports_basketball),
    SportOption(name: 'Tennis', icon: Icons.sports_tennis),
    SportOption(name: 'Soccer', icon: Icons.sports_soccer),
    SportOption(name: 'Running', icon: Icons.directions_run),
    SportOption(name: 'Swimming', icon: Icons.pool),
    SportOption(name: 'Cycling', icon: Icons.directions_bike),
    SportOption(name: 'Volleyball', icon: Icons.sports_volleyball),
    SportOption(name: 'Badminton', icon: Icons.sports_handball),
    SportOption(name: 'Fitness', icon: Icons.fitness_center),
    SportOption(name: 'Golf', icon: Icons.sports_golf),
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
    ref
        .read(sportPreferencesProvider.notifier)
        .setAll(_selected.map((k, v) => MapEntry(k, v.label)));
    ref.read(distanceFilterProvider.notifier).state = _distanceKm;
    ref.read(priceFilterProvider.notifier).state = _price.label;
  }

  int get _selectedCount => _selected.length;

  Map<SkillLevel, int> get _distribution {
    final m = <SkillLevel, int>{for (final s in SkillLevel.values) s: 0};
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
      parts.add('$_selectedCount ${_selectedCount == 1 ? 'sport' : 'sports'}');
    }
    parts.add('Within ${_distanceKm.toStringAsFixed(0)} km');
    parts.add(_price.label);
    return parts.join(' · ');
  }

  Future<void> _onTapSport(SportOption option) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => PreferencesSkillSheet(
        sportName: option.name,
        sportIcon: option.icon,
        current: _selected[option.name],
      ),
    );
    if (!mounted) return;
    if (result is SkillLevel) {
      setState(() => _selected[option.name] = result);
    } else if (result == kClearSportAction) {
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
    return AppScaffold.detail(
      title: 'Filters',
      showHomeIndicator: false, // reached from inside ShellRoute screens.
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x5,
                AppSpacing.x2,
                AppSpacing.x5,
                AppSpacing.x4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PreferencesHeroSummary(
                    count: _selectedCount,
                    dominant: _dominantSkill,
                    distribution: _distribution,
                    onReset: _selectedCount == 0 ? null : _reset,
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  const PreferencesSectionLabel(label: 'Your sports'),
                  const SizedBox(height: AppSpacing.x3),
                  PreferencesSportGrid(
                    sports: _sports,
                    selected: _selected,
                    onTap: _onTapSport,
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  PreferencesSectionLabel(
                    label: 'Distance',
                    trailing: Text(
                      'Within ${_distanceKm.toStringAsFixed(0)} km',
                      style: AppTypography.chipLabel(
                        context,
                      ).copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  PreferencesDistanceCard(
                    value: _distanceKm,
                    min: _minDistance,
                    max: _maxDistance,
                    onChanged: (v) => setState(() => _distanceKm = v),
                  ),
                  const SizedBox(height: AppSpacing.x6),
                  const PreferencesSectionLabel(label: 'Price preference'),
                  const SizedBox(height: AppSpacing.x3),
                  PreferencesPriceCard(
                    value: _price,
                    onChanged: (v) => setState(() => _price = v),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x2,
              AppSpacing.x5,
              AppSpacing.x3,
            ),
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
                const SizedBox(height: AppSpacing.x2),
                Text(
                  _filterSummary,
                  textAlign: TextAlign.center,
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
