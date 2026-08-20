import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/form_data_provider.dart';
import '../components/image_uploader.dart';
import '../components/wizard_field.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';

// AppColors, AppTypography used in sport picker sheet below.

/// Step 1: Cover Photo and Basic Information
class Step1CoverPhotoAndBasicInfo extends ConsumerStatefulWidget {
  const Step1CoverPhotoAndBasicInfo({super.key});

  @override
  ConsumerState<Step1CoverPhotoAndBasicInfo> createState() =>
      _Step1CoverPhotoAndBasicInfoState();
}

class _Step1CoverPhotoAndBasicInfoState
    extends ConsumerState<Step1CoverPhotoAndBasicInfo> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final formData = ref.read(formDataProvider);
    _titleController.text = formData.title;
    _descriptionController.text = formData.description;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    ref.read(formDataProvider.notifier).setTitle(value);
    ref.read(formDirtyFieldsProvider.notifier).markDirty('title');
  }

  void _onDescriptionChanged(String value) {
    ref.read(formDataProvider.notifier).setDescription(value);
  }

  @override
  Widget build(BuildContext context) {
    final formData = ref.watch(formDataProvider);
    final errors = ref.watch(formErrorsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x3,
        AppSpacing.x6,
        AppSpacing.x6,
      ),
      children: [
        // ── Cover Photo ────────────────────────────────────────────────
        ImageUploader(
          onImageSelected: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cover photo added')),
            );
          },
        ),
        const SizedBox(height: AppSpacing.x5),

        // ── Activity Title ─────────────────────────────────────────────
        WizardTextField(
          label: 'Activity Title *',
          controller: _titleController,
          hint: 'e.g. Weekend Basketball Runs',
          onChanged: _onTitleChanged,
          errorText: errors['title'],
        ),
        const SizedBox(height: AppSpacing.x4),

        // ── Sport Type ─────────────────────────────────────────────────
        _LabeledSelect(
          label: 'Sport Type *',
          value: formData.sportType,
          onTap: () => _showSportPicker(context),
        ),
        const SizedBox(height: AppSpacing.x4),

        // ── Description ────────────────────────────────────────────────
        WizardTextArea(
          label: 'Description',
          controller: _descriptionController,
          hint: 'Describe your activity...',
          onChanged: _onDescriptionChanged,
          maxLength: 500,
        ),
      ],
    );
  }

  void _showSportPicker(BuildContext context) {
    final formData = ref.read(formDataProvider);
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x6,
              AppSpacing.x3,
              AppSpacing.x6,
              AppSpacing.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Text(
                  'Select Sport',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),

                // Scrollable sport options — avoids overflow on short screens
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _sportOptions.length,
                    itemBuilder: (context, index) {
                      final opt = _sportOptions[index];
                      final selected = opt == formData.sportType;
                      return GestureDetector(
                        onTap: () {
                          ref
                              .read(formDataProvider.notifier)
                              .setSportType(opt);
                          Navigator.of(context).pop(opt);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.x3,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  opt,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(Icons.check,
                                    color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _sportOptions = [
    'Basketball',
    'Tennis',
    'Running',
    'Volleyball',
    'Football',
    'Soccer',
    'Cycling',
    'Hiking',
    'Golf',
    'Swimming',
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// _LabeledSelect — label + WizardSelectField in one block, matches WizardTextField
// ─────────────────────────────────────────────────────────────────────────────

class _LabeledSelect extends StatelessWidget {
  const _LabeledSelect({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardFieldLabel(label),
        const SizedBox(height: AppSpacing.x2),
        WizardSelectField(
          value: value,
          onTap: onTap,
        ),
      ],
    );
  }
}
