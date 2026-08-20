import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Standardized empty state: an icon in a soft tinted circle, a title, an
/// optional subtitle, and an optional primary action. Keeps every screen's
/// "nothing here" moment calm and consistent instead of a bare icon and two
/// lines of text (PRD Section 0.7).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

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
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.primaryDarker),
            ),
            const SizedBox(height: AppSpacing.x5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleSheet,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyReading.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.x6),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                size: AppButtonSize.sm,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
