import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_tappable.dart';
import '../../../core/widgets/pill_buttons.dart';
import '../../../core/widgets/pressable_scale.dart';
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
    return AppScaffold(
      showHomeIndicator: false, // inside ShellRoute — AppShell draws its own.
      body: Column(
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
                    style: AppTypography.titleScreen(context),
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'Pick any — then set your skill level.',
                    style: AppTypography.bodyMedium(
                      context,
                    ).copyWith(color: context.colors.textSecondary),
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
                        style: AppTypography.labelField(context),
                      ),
                      const Spacer(),
                      Text(
                        '${_distanceKm.round()} km',
                        style: AppTypography.chipLabel(
                          context,
                        ).copyWith(color: context.colors.primaryOnSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: context.colors.border,
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
        ],
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
    return AppTappable(
      semanticLabel: selected ? '$name, $level' : '$name, not selected',
      minSize: 0,
      borderRadius: AppRadius.lg,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.x3,
        ),
        decoration: BoxDecoration(
          color: selected ? context.colors.primarySoft : context.colors.surface,
          borderRadius: AppRadius.lgR,
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
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
                color: selected
                    ? AppColors.primary
                    : context.colors.surfaceSubtle,
                borderRadius: AppRadius.mdR,
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected
                    ? AppColors.textOnPrimary
                    : context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.x1 + 2),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.chipLabel(context).copyWith(
                color: selected
                    ? context.colors.primaryOnSurface
                    : context.colors.textLabel,
              ),
            ),
            const SizedBox(height: 3),
            if (selected && level != null)
              PressableScale(
                onTap: onLevelTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      level!.substring(0, 3), // abbreviate
                      style: AppTypography.caption(context).copyWith(
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
              Icon(
                Icons.add_rounded,
                size: 14,
                color: context.colors.textTertiary,
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
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
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
                color: context.colors.border,
                borderRadius: AppRadius.xsR,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(
              '$sport — Skill level',
              style: AppTypography.titleSheet(context),
            ),
            const SizedBox(height: AppSpacing.x4),
            ...levels.map(
              (l) => PressableScale(
                onTap: () => Navigator.of(context).pop(l),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: AppSpacing.x4,
                  ),
                  margin: const EdgeInsets.only(bottom: AppSpacing.x2),
                  decoration: BoxDecoration(
                    color: l == current
                        ? context.colors.primarySoft
                        : context.colors.surfaceSubtle,
                    borderRadius: AppRadius.mdR,
                    border: Border.all(
                      color: l == current
                          ? AppColors.primary
                          : context.colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l,
                          style: AppTypography.bodyMedium(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
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
