import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/dark_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pressable_scale.dart';
import 'get_to_know_1_screen.dart' show OnboardingProgressHeader;

class GetToKnow2Screen extends ConsumerStatefulWidget {
  const GetToKnow2Screen({super.key});

  @override
  ConsumerState<GetToKnow2Screen> createState() => _GetToKnow2ScreenState();
}

class _GetToKnow2ScreenState extends ConsumerState<GetToKnow2Screen> {
  /// Selected sports mapped to their skill level.
  final Map<String, String> _sports = {};

  static const _sportOptions = [
    'Basketball',
    'Tennis',
    'Soccer',
    'Running',
    'Volleyball',
    'Cycling',
    'Fitness',
    'Golf',
    'Swimming',
    'Badminton',
    'Squash',
    'Yoga',
  ];

  static const _levels = ['Beginner', 'Intermediate', 'Advanced'];

  double _distanceKm = 5;

  void _onNext() {
    ref.read(sportPreferencesProvider.notifier).setAll(_sports);
    ref.read(distanceFilterProvider.notifier).set(_distanceKm);
    context.push('/get-to-know-3');
  }

  /// Tapping a chip: an unselected sport asks for a skill level before it is
  /// added (so nothing is silently defaulted); a selected one is removed.
  Future<void> _onChipTap(String name) async {
    if (_sports.containsKey(name)) {
      setState(() => _sports.remove(name));
      return;
    }
    final picked = await _showLevelSheet(name, null);
    if (picked != null) setState(() => _sports[name] = picked);
  }

  /// Re-opens the picker for an already-selected sport.
  Future<void> _onLevelTap(String name, String current) async {
    final picked = await _showLevelSheet(name, current);
    if (picked != null) setState(() => _sports[name] = picked);
  }

  Future<String?> _showLevelSheet(String sport, String? current) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _LevelSheet(sport: sport, current: current, levels: _levels),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AppScaffold(
      // Outside ShellRoute (post-signup flow, no tab bar) — draws its own.
      showHomeIndicator: true,
      backgroundColor: context.colors.surface,
      body: Column(
        children: [
          OnboardingProgressHeader(step: 2, total: 3),

          // ── Scrollable: title + sport grid ─────────────────────────
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
                    'Which sports do you play?',
                    style: AppTypography.titleScreen(context).copyWith(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    'Pick any - then set your skill level.',
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  // Sport grid — 3 columns of oval chips
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppSpacing.x3,
                      mainAxisSpacing: AppSpacing.x3,
                      childAspectRatio: 1.45,
                    ),
                    itemCount: _sportOptions.length,
                    itemBuilder: (_, i) {
                      final name = _sportOptions[i];
                      final level = _sports[name];
                      return _SportChip(
                        name: name,
                        level: level,
                        onTap: () => _onChipTap(name),
                        onLevelTap: level != null
                            ? () => _onLevelTap(name, level)
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Discovery distance ─────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.colors.border),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x4,
              AppSpacing.x5,
              AppSpacing.x3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Discovery distance',
                      style: AppTypography.labelField(context).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_distanceKm.round()} km',
                      style: AppTypography.labelField(context).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
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
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: _distanceKm,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    onChanged: (v) => setState(() => _distanceKm = v),
                  ),
                ),
              ],
            ),
          ),

          // ── Next button ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.colors.border),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.x5,
              AppSpacing.x4,
              AppSpacing.x5,
              bottomPad + AppSpacing.x3,
            ),
            child: PressableScale(
              onTap: _onNext,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadows.glowPrimary,
                ),
                alignment: Alignment.center,
                child: Text(
                  _sports.isEmpty
                      ? 'Skip for now'
                      : 'Next (${_sports.length} selected)',
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

// ─── Sport chip — oval, no icon ───────────────────────────────────────────────

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.name,
    required this.level,
    required this.onTap,
    this.onLevelTap,
  });

  final String name;
  final String? level;
  final VoidCallback onTap;
  final VoidCallback? onLevelTap;

  static const Color _unselectedFill = Color(0xFFF1F5F9);
  static const Color _unselectedBorder = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final selected = level != null;

    // PressableScale (not AppTappable) because AppTappable wraps its child in
    // a Stack, which lets the container shrink to its content instead of
    // filling the grid cell — the chip must stretch edge-to-edge.
    return Semantics(
      button: true,
      label: selected ? '$name, $level' : '$name, not selected',
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected ? context.colors.primarySoft : _unselectedFill,
            // Radius just under half the cell height reads as a soft oval.
            borderRadius: BorderRadius.circular(52),
            border: Border.all(
              color: selected
                  ? context.colors.primaryOnSurface
                  : _unselectedBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelField(context).copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? context.colors.primaryOnSurface
                      : context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              if (selected)
                PressableScale(
                  onTap: onLevelTap,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        level!.substring(0, 3),
                        style: AppTypography.caption(context).copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.colors.primaryOnSurface,
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 15,
                        color: context.colors.primaryOnSurface,
                      ),
                    ],
                  ),
                )
              else
                Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: context.colors.textSecondary,
                ),
            ],
          ),
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

  /// `null` when the sport is being added for the first time — nothing is
  /// pre-selected, so the user has to make a deliberate choice.
  final String? current;

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
          AppSpacing.x5,
          AppSpacing.x3,
          AppSpacing.x5,
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
            Text(sport, style: AppTypography.titleSheet(context)),
            const SizedBox(height: 4),
            Text(
              current == null
                  ? 'How would you rate your skill level?'
                  : 'Update your skill level',
              style: AppTypography.bodyFormSecondary(context),
            ),
            const SizedBox(height: AppSpacing.x4),
            ...levels.map((l) {
              final isCurrent = l == current;
              return PressableScale(
                onTap: () => Navigator.of(context).pop(l),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  margin: const EdgeInsets.only(bottom: AppSpacing.x2),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? context.colors.primarySoft
                        : context.colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: isCurrent
                          ? context.colors.primaryOnSurface
                          : context.colors.border,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l,
                          style: AppTypography.bodyMedium(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: isCurrent
                                ? context.colors.primaryOnSurface
                                : context.colors.textPrimary,
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: context.colors.primaryOnSurface,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
