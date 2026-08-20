import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/form_data_provider.dart';
import '../components/wizard_field.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/date_picker_sheet.dart';

/// Step 2: Schedule & Venue — Date, Location, and Max Participants
class Step2DateLocationDescription extends ConsumerStatefulWidget {
  const Step2DateLocationDescription({super.key});

  @override
  ConsumerState<Step2DateLocationDescription> createState() =>
      _Step2State();
}

class _Step2State extends ConsumerState<Step2DateLocationDescription> {
  final _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  int _maxParticipants = 10;

  @override
  void initState() {
    super.initState();
    final formData = ref.read(formDataProvider);
    _locationController.text = formData.location;
    _maxParticipants = formData.maxParticipants;
    if (formData.selectedDate != null) {
      _selectedDate = formData.selectedDate!;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  void _onLocationChanged(String value) {
    ref.read(formDataProvider.notifier).setLocation(value);
    ref.read(formDirtyFieldsProvider.notifier).markDirty('location');
  }

  void _onParticipantsChanged(int value) {
    setState(() => _maxParticipants = value);
    ref.read(formDataProvider.notifier).setMaxParticipants(value);
    ref.read(formDirtyFieldsProvider.notifier).markDirty('maxParticipants');
  }

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DatePickerSheet(
        initialDate: _selectedDate,
        minDate: DateTime.now(),
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      ref.read(formDataProvider.notifier).setSelectedDate(picked);
      ref.read(formDirtyFieldsProvider.notifier).markDirty('selectedDate');
    }
  }

  @override
  Widget build(BuildContext context) {
    final errors = ref.watch(formErrorsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x4,
        AppSpacing.x6,
        AppSpacing.x6,
      ),
      children: [
        // ── Date & Time ────────────────────────────────────────────────
        _LabeledSelect(
          label: 'Date & Time *',
          value: _formatDate(_selectedDate),
          leadingIcon: Icons.calendar_today_outlined,
          hasError: errors['selectedDate'] != null,
          errorText: errors['selectedDate'],
          onTap: _pickDate,
        ),
        const SizedBox(height: AppSpacing.x4),

        // ── Location ───────────────────────────────────────────────────
        WizardTextField(
          label: 'Location *',
          controller: _locationController,
          hint: 'Where will it take place?',
          leadingIcon: Icons.location_on_outlined,
          onChanged: _onLocationChanged,
          errorText: errors['location'],
        ),
        const SizedBox(height: AppSpacing.x4),

        // ── Max Participants ───────────────────────────────────────────
        _ParticipantsField(
          value: _maxParticipants,
          errorText: errors['maxParticipants'],
          onDecrement: _maxParticipants > 2
              ? () => _onParticipantsChanged(_maxParticipants - 1)
              : null,
          onIncrement: _maxParticipants < 50
              ? () => _onParticipantsChanged(_maxParticipants + 1)
              : null,
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hour12 =
        dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${dt.month}/${dt.day}, $hour12:$min $ampm';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LabeledSelect — label + WizardSelectField + optional error text
// ─────────────────────────────────────────────────────────────────────────────

class _LabeledSelect extends StatelessWidget {
  const _LabeledSelect({
    required this.label,
    required this.value,
    required this.onTap,
    this.leadingIcon,
    this.hasError = false,
    this.errorText,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final bool hasError;
  final String? errorText;

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
          leadingIcon: leadingIcon,
          hasError: hasError,
        ),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.x1),
          Text(
            errorText!,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ParticipantsField — stepper row with label
// ─────────────────────────────────────────────────────────────────────────────

class _ParticipantsField extends StatelessWidget {
  const _ParticipantsField({
    required this.value,
    this.errorText,
    this.onDecrement,
    this.onIncrement,
  });

  final int value;
  final String? errorText;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WizardFieldLabel('Max Participants'),
        const SizedBox(height: AppSpacing.x2),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: hasError ? AppColors.danger : AppColors.borderInput,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value people',
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Including yourself',
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _StepBtn(
                icon: Icons.remove,
                enabled: onDecrement != null,
                onTap: onDecrement,
              ),
              const SizedBox(width: AppSpacing.x2),
              _StepBtn(
                icon: Icons.add,
                enabled: onIncrement != null,
                onTap: onIncrement,
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.x1),
          Text(
            errorText!,
            style: AppTypography.bodySmall
                .copyWith(color: AppColors.danger, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primarySoft : AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.primary : AppColors.textTertiary,
        ),
      ),
    );
  }
}
