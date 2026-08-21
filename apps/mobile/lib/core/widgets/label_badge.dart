import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/dark_colors.dart';

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
        borderRadius: AppRadius.pillR,
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall(context).copyWith(
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

  @override
  Widget build(BuildContext context) {
    final isChecked = tone == StatusTone.checkedIn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // Was a separately hardcoded #D1FAE5/#097044 pair — consolidated onto
        // the existing success status tokens (already #D1FAE5/#04694A used by
        // the discovery "Open" chip) so the app carries one success-green
        // family instead of two near-duplicates (PRD Appendix C.2).
        color: isChecked
            ? context.colors.statusSuccessBg
            : context.colors.surface,
        borderRadius: AppRadius.pillR,
        border: isChecked ? null : Border.all(color: context.colors.border),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall(context).copyWith(
          color: isChecked
              ? AppColors.statusSuccessText
              : context.colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
