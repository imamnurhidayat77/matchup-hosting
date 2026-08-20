import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/home_indicator.dart';
import '../../../core/widgets/pill_buttons.dart';

// Persists the selected reason so it's available to analytics / onboarding
// flow without cluttering a global provider. Local state is enough here.

class GetToKnow1Screen extends ConsumerStatefulWidget {
  const GetToKnow1Screen({super.key});

  @override
  ConsumerState<GetToKnow1Screen> createState() => _GetToKnow1ScreenState();
}

class _GetToKnow1ScreenState extends ConsumerState<GetToKnow1Screen> {
  int _selected = 0;

  static const _options = [
    ('Stay active with new sports',        Icons.directions_run_rounded),
    ('Build consistent workout habits',    Icons.fitness_center_rounded),
    ('Find a motivating sports community', Icons.group_rounded),
    ('Meet new sports partners',           Icons.handshake_rounded),
    ('Other reasons',                      Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            OnboardingProgressHeader(step: 1, total: 3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x6,
                  AppSpacing.x6,
                  AppSpacing.x6,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's your primary\nreason for joining MatchUp?",
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3),
                    Text(
                      'Pick one that resonates most.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x5),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _options.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.x3),
                        itemBuilder: (_, i) => _OptionTile(
                          icon: _options[i].$2,
                          label: _options[i].$1,
                          selected: i == _selected,
                          onTap: () => setState(() => _selected = i),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    PrimaryPillButton(
                      label: 'Next',
                      onPressed: () => context.push('/get-to-know-2'),
                    ),
                    const SizedBox(height: AppSpacing.x2),
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
}

// ─── Shared widgets used by both get-to-know screens ─────────────────────────

/// Minimal step progress bar shown across all onboarding steps.
/// Public so it can be reused by get_to_know_2_screen.dart.
class OnboardingProgressHeader extends StatelessWidget {
  const OnboardingProgressHeader({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x3,
        AppSpacing.x6,
        AppSpacing.x2,
      ),
      child: Column(
        children: [
          Row(
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
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  "LET'S GET TO KNOW YOU",
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryDarker,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                '$step/$total',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          // Step progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: step / total,
              minHeight: 4,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x5,
            vertical: AppSpacing.x4,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              // Radio dot
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.borderInput,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
