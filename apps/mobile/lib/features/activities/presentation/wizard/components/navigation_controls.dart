import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/providers/repository_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../providers/form_data_provider.dart';
import '../providers/wizard_controller_provider.dart';
import '../services/draft_storage.dart';
import '../services/form_validator.dart';

/// Back / Next / Submit bar at the bottom of the wizard.
class NavigationControls extends ConsumerStatefulWidget {
  const NavigationControls({super.key});

  @override
  ConsumerState<NavigationControls> createState() =>
      _NavigationControlsState();
}

class _NavigationControlsState extends ConsumerState<NavigationControls> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(wizardControllerProvider);
    // Use allFormErrors (unfiltered) so the Next button is disabled when the
    // step is actually invalid, regardless of dirty state.
    final allErrors = ref.watch(allFormErrorsProvider);
    final stepValid = _stepErrors(ctrl.currentStep, allErrors).isEmpty;

    return Row(
      children: [
        // Back — hidden on step 1
        if (!ctrl.isFirstStep) ...[
          Expanded(
            child: _BackButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(wizardControllerProvider.notifier).previousStep();
              },
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
        ],

        // Next / Submit
        Expanded(
          flex: ctrl.isFirstStep ? 1 : 2,
          child: _NextButton(
            isLastStep: ctrl.isLastStep,
            loading: _submitting,
            disabled: !stepValid,
            onTap: () => _handleNext(context, ctrl),
          ),
        ),
      ],
    );
  }

  // ── Step validation helpers ───────────────────────────────────────────────

  /// Returns only the error entries relevant to the current step.
  /// Empty map = step is valid.
  Map<String, String> _stepErrors(int step, Map<String, String> all) {
    final relevant = <String>[];
    switch (step) {
      case 1:
        relevant.addAll(['title']);
      case 2:
        relevant.addAll(['location', 'selectedDate', 'maxParticipants']);
      case 3:
        break; // skill + fee/review — no mandatory fields
    }
    return {
      for (final k in relevant)
        if (all[k] != null && all[k]!.isNotEmpty) k: all[k]!,
    };
  }

  // ── Navigation logic ──────────────────────────────────────────────────────

  Future<void> _handleNext(
    BuildContext context,
    WizardController ctrl,
  ) async {
    HapticFeedback.lightImpact();

    // Mark current step fields as dirty so errors become visible if invalid.
    ref.read(formDirtyFieldsProvider.notifier).markStepDirty(ctrl.currentStep);

    // Auto-save draft on every step transition
    final formData = ref.read(formDataProvider);
    try {
      await ref.read(draftStorageProvider).saveDraft(formData, ctrl.currentStep);
    } catch (_) {
      // Draft save is best-effort — don't block navigation
    }

    if (ctrl.isLastStep) {
      // ignore: use_build_context_synchronously
      await _submit(context);
    } else {
      final notifier = ref.read(wizardControllerProvider.notifier);
      notifier.completeStep(ctrl.currentStep);
      notifier.nextStep();
    }
  }

  Future<void> _submit(BuildContext context) async {
    if (_submitting) return;

    final formData = ref.read(formDataProvider);
    final allErrors = formValidator(formData);

    if (allErrors.isNotEmpty) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            'Please fix ${allErrors.length} issue${allErrors.length == 1 ? '' : 's'} before creating.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(activityRepositoryProvider).create(
            title: formData.title.trim(),
            sportType: formData.sportType,
            location: formData.location.trim(),
            dateTime: formData.selectedDate ?? DateTime.now().add(const Duration(days: 1)),
            maxParticipants: formData.maxParticipants,
            skillLevel: formData.skillLevel,
            fee: formData.feeType == 1
                ? double.tryParse(formData.price ?? '0') ?? 0
                : 0.0,
          );

      await ref.read(draftStorageProvider).clearDraft();
      ref.read(wizardControllerProvider.notifier).reset();
      ref.read(formDataProvider.notifier).reset();

      if (!mounted) return;

      HapticFeedback.heavyImpact();
      // ignore: use_build_context_synchronously
      AppSnackbar.show(context, message: 'Activity created! 🎉', variant: AppSnackbarVariant.success);
      // ignore: use_build_context_synchronously
      context.go('/activities');
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      AppSnackbar.show(context, message: 'Could not create activity. Please try again.', variant: AppSnackbarVariant.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ─── Back button ──────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_back_rounded,
                size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              'Back',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Next / Submit button ─────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.isLastStep,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  final bool isLastStep;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = !disabled && !loading;

    return GestureDetector(
      onTap: active ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: 52,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: active ? AppShadows.glowPrimary : null,
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                isLastStep ? 'Create Activity' : 'Next',
                style: AppTypography.buttonPrimary.copyWith(
                  color: active ? Colors.white : AppColors.textTertiary,
                ),
              ),
      ),
    );
  }
}
