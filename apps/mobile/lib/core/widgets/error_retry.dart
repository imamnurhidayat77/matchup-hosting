import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Full-page error state with retry CTA.
/// Drop into `AsyncValue.when(error: (e, _) => ErrorRetry(onRetry: ref.refresh))`.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    this.message = 'Something went wrong. Please try again.',
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
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
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
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
