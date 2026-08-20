import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/activity_model.dart';
import 'providers/wizard_controller_provider.dart';
import 'providers/form_data_provider.dart';
import 'providers/image_upload_provider.dart';
import 'components/progress_indicator.dart';
import 'components/navigation_controls.dart';
import 'steps/step1_cover_photo_and_basic_info.dart';
import 'steps/step2_date_location_description.dart';
import 'steps/step3_participants_skill_level.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';

/// Main wizard container widget
class CreateActivityWizard extends ConsumerStatefulWidget {
  const CreateActivityWizard({
    super.key,
    this.initialStep = 1,
    this.existingActivity,
  });

  final int initialStep;
  final ActivityModel? existingActivity;

  @override
  ConsumerState<CreateActivityWizard> createState() =>
      _CreateActivityWizardState();
}

class _CreateActivityWizardState extends ConsumerState<CreateActivityWizard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always reset transient state so a re-opened wizard is clean.
      ref.read(imageUploadProvider.notifier).reset();
      ref.read(formDirtyFieldsProvider.notifier).reset();

      // Set initial step
      ref.read(wizardControllerProvider.notifier).setStep(widget.initialStep);

      // Pre-fill form from existing activity if editing
      if (widget.existingActivity != null) {
        final a = widget.existingActivity!;
        ref.read(formDataProvider.notifier)
          ..setTitle(a.title)
          ..setSportType(a.sportType)
          ..setLocation(a.location)
          ..setSelectedDate(a.dateTime)
          ..setDescription(a.description)
          ..setMaxParticipants(a.capacity)
          ..setSkillLevel(a.skillLevel);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(wizardCurrentStepProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x6,
                AppSpacing.x3,
                AppSpacing.x6,
                AppSpacing.x2,
              ),
              child: const WizardProgressIndicator(),
            ),

            // Step content — slide+fade transition between steps
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.base,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: KeyedSubtree(
                  key: ValueKey(step),
                  child: _buildStep(step),
                ),
              ),
            ),

            // Navigation bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x6,
                AppSpacing.x3,
                AppSpacing.x6,
                AppSpacing.x6,
              ),
              child: const NavigationControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 1:
        return const Step1CoverPhotoAndBasicInfo();
      case 2:
        return const Step2DateLocationDescription();
      case 3:
        return const Step3ParticipantsAndSkillLevel();
      default:
        return const Step1CoverPhotoAndBasicInfo();
    }
  }
}
