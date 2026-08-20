import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/form_data_provider.dart';
import '../components/wizard_field.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';

/// Step 4: Fee, Price, and Review Summary
class Step4FeeAndReview extends ConsumerStatefulWidget {
  const Step4FeeAndReview({super.key});

  @override
  ConsumerState<Step4FeeAndReview> createState() => _Step4FeeAndReviewState();
}

class _Step4FeeAndReviewState extends ConsumerState<Step4FeeAndReview> {
  int _feeType = 0; // 0 = Free, 1 = Paid
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final formData = ref.read(formDataProvider);
    _feeType = formData.feeType;
    // Price controller stores only the numeric value (no $ sign).
    if (formData.price != null) {
      _priceController.text = formData.price!;
    } else {
      _priceController.text = '5.00';
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _onFeeTypeChanged(int index) {
    setState(() {
      _feeType = index;
      if (index == 0) {
        _priceController.text = '';
        ref.read(formDataProvider.notifier).setPrice(null);
      } else {
        if (_priceController.text.isEmpty) {
          _priceController.text = '5.00';
        }
        ref.read(formDataProvider.notifier).setPrice(_priceController.text.trim());
      }
    });
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
        // Event Fee
        Text(
          'Event Fee',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(AppSpacing.x1),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _onFeeTypeChanged(0),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: _feeType == 0 ? AppColors.primary : null,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                      child: Text(
                        'Free',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: _feeType == 0 ? FontWeight.w700 : FontWeight.w600,
                          color: _feeType == 0 ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _onFeeTypeChanged(1),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: _feeType == 1 ? AppColors.primary : null,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                      child: Text(
                        'Paid',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 12,
                          fontWeight: _feeType == 1 ? FontWeight.w700 : FontWeight.w600,
                          color: _feeType == 1 ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
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
        const SizedBox(height: 32),

        // Preview Card
        _PreviewCard(formData: formData, feeType: _feeType, price: _priceController.text),
      ],
    );
  }
}

/// Mini preview card showing how the activity will appear
class _PreviewCard extends StatelessWidget {
  final ActivityFormData formData;
  final int feeType;
  final String price;

  const _PreviewCard({
    required this.formData,
    required this.feeType,
    required this.price,
  });

  String get _feeLabel =>
      feeType == 0 ? 'Free' : (price.isNotEmpty ? '\$$price' : 'Paid');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREVIEW',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        // Create a simple preview card using existing ActivityCard
        // Note: This is a simplified version since we don't have all the fields
        // In a real implementation, we would create a proper preview component
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover photo placeholder
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Center(
                  child: Icon(Icons.camera_alt_outlined, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                formData.title.isNotEmpty ? formData.title : 'Untitled activity',
                style: AppTypography.headlineSmall.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Sport Type
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  formData.sportType.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        formData.location.isNotEmpty ? formData.location : 'Location not set',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        formData.selectedDate != null
                            ? '${formData.selectedDate!.month}/${formData.selectedDate!.day}'
                            : 'Date not set',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hosted by you',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _feeLabel,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primaryDarker,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'This is how others will see your activity.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}