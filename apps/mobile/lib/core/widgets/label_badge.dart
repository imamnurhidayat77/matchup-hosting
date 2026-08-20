import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Pill-shaped label matching Figma activity badges (e.g. "BASKETBALL",
/// "CONFIRMED", "JOINED"). Stadium shape, 11px bold text, configurable
/// background/foreground so the same widget covers status badges across
/// screens.
class LabelBadge extends StatelessWidget {
  const LabelBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final String label;
  final Color background;
  final Color foreground;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: foreground,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Status badge variant that derives its colors from a [StatusTone]. Used for
/// participant check-in state in joined-activity flows.
enum StatusTone { checkedIn, pending }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  static const _checkedBg = Color(0xFFD1FAE5);
  static const _checkedFg = Color(0xFF097044);

  @override
  Widget build(BuildContext context) {
    final isChecked = tone == StatusTone.checkedIn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isChecked ? _checkedBg : AppColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: isChecked ? null : Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: isChecked ? _checkedFg : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
