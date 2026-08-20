import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';
import 'get_to_know_1_screen.dart' show OnboardingProgressHeader;

class GetToKnow2Screen extends ConsumerStatefulWidget {
  const GetToKnow2Screen({super.key});

  @override
  ConsumerState<GetToKnow2Screen> createState() => _GetToKnow2ScreenState();
}

class _GetToKnow2ScreenState extends ConsumerState<GetToKnow2Screen> {
  // ── Sport selection (name → skill level label) ───────────────────────────
  final Map<String, String> _sports = {};

  static const _sportOptions = [
    ('Basketball', Icons.sports_basketball_rounded),
    ('Tennis', Icons.sports_tennis_rounded),
    ('Soccer', Icons.sports_soccer_rounded),
    ('Running', Icons.directions_run_rounded),
    ('Volleyball', Icons.sports_volleyball_rounded),
    ('Cycling', Icons.directions_bike_rounded),
    ('Fitness', Icons.fitness_center_rounded),
    ('Golf', Icons.sports_golf_rounded),
    ('Swimming', Icons.pool_rounded),
    ('Badminton', Icons.sports_handball_rounded),
  ];

  static const _levels = ['Beginner', 'Intermediate', 'Advanced'];

  // ── Distance preference ───────────────────────────────────────────────────
  double _distanceKm = 5;

  void _onNext() {
    // Persist to shared providers so preferences_screen & discovery read them
    ref.read(sportPreferencesProvider.notifier).setAll(_sports);
    ref.read(distanceFilterProvider.notifier).state = _distanceKm;
    context.push('/preferences');
  }

  void _toggleSport(String name) {
    setState(() {
      if (_sports.containsKey(name)) {
        _sports.remove(name);
      } else {
        _sports[name] = 'Intermediate'; // default level
      }
    });
  }

  void _setLevel(String name, String level) {
    setState(() => _sports[name] = level);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            OnboardingProgressHeader(step: 2, total: 3),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x6,
                  AppSpacing.x4,
                  AppSpacing.x6,
                  AppSpacing.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Which sports do you play?',
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      'Pick any — then set your skill level.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x5),

                    // ── Sport grid ─────────────────────────────────────
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: AppSpacing.x3,
                            mainAxisSpacing: AppSpacing.x3,
                            childAspectRatio: 0.9,
                          ),
                      itemCount: _sportOptions.length,
                      itemBuilder: (_, i) {
                        final (name, icon) = _sportOptions[i];
                        final level = _sports[name];
                        final selected = level != null;
                        return _SportChip(
                          icon: icon,
                          name: name,
                          level: level,
                          selected: selected,
                          onTap: () => _toggleSport(name),
                          onLevelTap: selected
                              ? () => _showLevelSheet(context, name, level)
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.x6),

                    // ── Distance ───────────────────────────────────────
                    Row(
                      children: [
                        Text(
                          'Discovery distance',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_distanceKm.round()} km',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primaryDarker,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.border,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.12),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 9,
                        ),
                      ),
                      child: Slider(
                        value: _distanceKm,
                        min: 1,
                        max: 50,
                        divisions: 49,
                        onChanged: (v) => setState(() => _distanceKm = v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x6),

                    PrimaryPillButton(
                      label: _sports.isEmpty
                          ? 'Skip for now'
                          : 'Next  (${_sports.length} selected)',
                      onPressed: _onNext,
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

  Future<void> _showLevelSheet(
    BuildContext context,
    String sport,
    String current,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _LevelSheet(sport: sport, current: current, levels: _levels),
    );
    if (picked != null) _setLevel(sport, picked);
  }
}

// ─── Sport chip ───────────────────────────────────────────────────────────────

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.icon,
    required this.name,
    required this.level,
    required this.selected,
    required this.onTap,
    this.onLevelTap,
  });

  final IconData icon;
  final String name;
  final String? level;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLevelTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primaryDarker : AppColors.textLabel,
              ),
            ),
            const SizedBox(height: 3),
            if (selected && level != null)
              GestureDetector(
                onTap: onLevelTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      level!.substring(0, 3), // abbreviate
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              )
            else
              const Icon(
                Icons.add_rounded,
                size: 14,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Level picker sheet ───────────────────────────────────────────────────────

class _LevelSheet extends StatelessWidget {
  const _LevelSheet({
    required this.sport,
    required this.current,
    required this.levels,
  });

  final String sport;
  final String current;
  final List<String> levels;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x6,
          AppSpacing.x3,
          AppSpacing.x6,
          AppSpacing.x5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              '$sport — Skill level',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            ...levels.map(
              (l) => GestureDetector(
                onTap: () => Navigator.of(context).pop(l),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: AppSpacing.x4,
                  ),
                  margin: const EdgeInsets.only(bottom: AppSpacing.x2),
                  decoration: BoxDecoration(
                    color: l == current
                        ? AppColors.primarySoft
                        : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: l == current
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (l == current)
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
