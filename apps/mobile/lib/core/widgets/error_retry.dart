import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Full-page error state with retry CTA.
/// Drop into `AsyncValue.when(error: (e, _) => ErrorRetry(onRetry: ref.refresh))`.
///
/// Visually the same family as [EmptyState] — soft tinted icon circle,
/// title, body copy, single action — but tinted [AppColors.danger] instead
/// of [AppColors.primary] so an error reads as distinct from an empty list.
/// The heading and copy avoid an exclamation mark and the word "Oops" on
/// purpose: a calm, direct statement reads as more trustworthy than a
/// startled one (PRD Appendix C.2).
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    this.message = "Couldn't load this. Please try again.",
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.x5),
            Text(
              "Something didn't load",
              textAlign: TextAlign.center,
              style: AppTypography.titleSheet,
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyReading.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.x6),
            AppButton(
              label: 'Try again',
              onPressed: onRetry,
              expand: false,
              size: AppButtonSize.sm,
            ),
          ],
        ),
      ),
    );
  }
}
