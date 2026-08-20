import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wizard_controller_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';

/// Step progress indicator for the create-activity wizard.
/// Named [WizardProgressIndicator] to avoid conflict with Flutter's
/// built-in [ProgressIndicator] widget.
class WizardProgressIndicator extends ConsumerWidget {
  const WizardProgressIndicator({super.key});

  static const _stepLabels = ['Activity', 'Schedule', 'Details'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStep = ref.watch(wizardCurrentStepProvider);
    final completedSteps = ref.watch(wizardCompletedStepsProvider);

    return Column(
      children: [
        // Step label row — step number left, label right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step $currentStep of 3',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _stepLabels[currentStep - 1],
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),

        // Pill-bar progress track — 3 segments
        Row(
          children: List.generate(3, (i) {
            final step = i + 1;
            final isCompleted = completedSteps.contains(step);
            final isActive = step == currentStep;
            final isEnabled = step < currentStep || isCompleted;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 2 ? AppSpacing.x1 : 0),
                child: GestureDetector(
                  onTap: isEnabled
                      ? () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(wizardControllerProvider.notifier)
                              .setStep(step);
                        }
                      : null,
                  child: _SegmentBar(
                    isActive: isActive,
                    isCompleted: isCompleted,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.isActive, required this.isCompleted});

  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (isActive) {
      color = AppColors.primary;
    } else if (isCompleted) {
      color = AppColors.primary.withValues(alpha: 0.35);
    } else {
      color = AppColors.border;
    }

    return AnimatedContainer(
      duration: AppDurations.base,
      curve: Curves.easeOut,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
