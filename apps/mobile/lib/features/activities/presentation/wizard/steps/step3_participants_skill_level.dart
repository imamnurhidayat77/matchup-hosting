import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/form_data_provider.dart';
import '../components/wizard_field.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';

/// Step 3 (final): Skill Level, Fee, and Activity Preview
class Step3ParticipantsAndSkillLevel extends ConsumerStatefulWidget {
  const Step3ParticipantsAndSkillLevel({super.key});

  @override
  ConsumerState<Step3ParticipantsAndSkillLevel> createState() =>
      _Step3State();
}

class _Step3State extends ConsumerState<Step3ParticipantsAndSkillLevel> {
  int _selectedSkillLevel = 1;
  int _feeType = 0;
  final _priceController = TextEditingController();

  static const _skillLevels = ['Beginner', 'Intermediate', 'Advanced'];
  static const _skillSubtitles = [
    'New to this sport',
    'Some experience',
    'Experienced player',
  ];
  static const _skillIcons = [
    Icons.eco_outlined,
    Icons.bolt_outlined,
    Icons.local_fire_department_outlined,
  ];

  @override
  void initState() {
    super.initState();
    final formData = ref.read(formDataProvider);
    _selectedSkillLevel = _skillLevels.indexOf(formData.skillLevel);
    if (_selectedSkillLevel < 0) _selectedSkillLevel = 1;
    _feeType = formData.feeType;
    _priceController.text = formData.price ?? '5.00';
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _onSkillLevelSelected(int index) {
    setState(() => _selectedSkillLevel = index);
    ref.read(formDataProvider.notifier).setSkillLevel(_skillLevels[index]);
  }

  void _onFeeTypeChanged(int index) {
    setState(() {
      _feeType = index;
      if (index == 0) {
        ref.read(formDataProvider.notifier).setPrice(null);
      } else {
        if (_priceController.text.isEmpty) _priceController.text = '5.00';
        ref.read(formDataProvider.notifier).setPrice(_priceController.text.trim());
      }
    });
    ref.read(formDataProvider.notifier).setFeeType(index);
  }

  void _onPriceChanged(String value) {
    final cleaned = value.trim();
    if (cleaned.isNotEmpty) {
      ref.read(formDataProvider.notifier).setPrice(cleaned);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formData = ref.watch(formDataProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x4,
        AppSpacing.x6,
        AppSpacing.x6,
      ),
      children: [
        // ── Skill Level ────────────────────────────────────────────────
        const WizardFieldLabel('Skill Level *'),
        const SizedBox(height: AppSpacing.x2),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderInput),
          ),
          child: Column(
            children: List.generate(_skillLevels.length, (i) {
              final selected = i == _selectedSkillLevel;
              final isLast = i == _skillLevels.length - 1;
              return Column(
                children: [
                  _SkillTile(
                    icon: _skillIcons[i],
                    label: _skillLevels[i],
                    subtitle: _skillSubtitles[i],
                    isSelected: selected,
                    onTap: () => _onSkillLevelSelected(i),
                  ),
                  if (!isLast)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                      child: Divider(height: 1, color: AppColors.border),
                    ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.x4),

        // ── Event Fee ──────────────────────────────────────────────────
        const WizardFieldLabel('Event Fee'),
        const SizedBox(height: AppSpacing.x2),
        Container(
          padding: const EdgeInsets.all(AppSpacing.x1),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.borderInput),
          ),
          child: Row(
            children: [
              _FeeTab(
                label: 'Free',
                active: _feeType == 0,
                onTap: () => _onFeeTypeChanged(0),
              ),
              _FeeTab(
                label: 'Paid',
                active: _feeType == 1,
                onTap: () => _onFeeTypeChanged(1),
              ),
            ],
          ),
        ),
        if (_feeType == 1) ...[
          const SizedBox(height: AppSpacing.x3),
          WizardTextField(
            label: 'Price *',
            controller: _priceController,
            hint: '0.00',
            prefixText: '\$',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onChanged: _onPriceChanged,
          ),
        ],
        const SizedBox(height: AppSpacing.x6),

        // ── Preview card ───────────────────────────────────────────────
        _PreviewSection(
          formData: formData,
          feeType: _feeType,
          price: _priceController.text,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SkillTile
// ─────────────────────────────────────────────────────────────────────────────

class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primarySoft : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color:
                      isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: AppDurations.base,
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color:
                      isSelected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FeeTab
// ─────────────────────────────────────────────────────────────────────────────

class _FeeTab extends StatelessWidget {
  const _FeeTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.base,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.x2,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PreviewSection
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.formData,
    required this.feeType,
    required this.price,
  });

  final ActivityFormData formData;
  final int feeType;
  final String price;

  String get _feeLabel =>
      feeType == 0 ? 'Free' : (price.isNotEmpty ? '\$$price' : 'Paid');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.border,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
              child: Text(
                'PREVIEW',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: AppColors.border)),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover placeholder
              Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  size: 28,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              // Title + sport badge row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      formData.title.isNotEmpty
                          ? formData.title
                          : 'Untitled activity',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2, vertical: AppSpacing.x1),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      formData.sportType.toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              // Meta row
              Row(
                children: [
                  _MetaChip(
                    icon: Icons.location_on_outlined,
                    label: formData.location.isNotEmpty
                        ? formData.location
                        : 'Location TBD',
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    label: formData.selectedDate != null
                        ? '${formData.selectedDate!.month}/${formData.selectedDate!.day}'
                        : 'Date TBD',
                  ),
                  const Spacer(),
                  Text(
                    _feeLabel,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'This is how your activity will appear to others.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
