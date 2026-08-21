import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/dark_colors.dart';
import 'pressable_scale.dart';

/// Pill-style segmented control (like iOS UISegmentedControl) used for
/// tabs that don't need full navigation (e.g. Upcoming/Hosting/Past,
/// Unread/All).
///
/// ```dart
/// AppSegmentedControl(
///   labels: const ['Upcoming', 'Hosting', 'Past'],
///   selectedIndex: _tab,
///   onChanged: (i) => setState(() => _tab = i),
/// )
/// ```
class AppSegmentedControl extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 40,
    this.activeLabelColor,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  /// Colour of the selected segment's label. Defaults to
  /// `primaryOnSurface`; pass `textPrimary` for a neutral high-contrast
  /// treatment where the white pill alone carries the selected state.
  final Color? activeLabelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: PressableScale(
              onTap: () {
                if (i != selectedIndex) {
                  HapticFeedback.selectionClick();
                  onChanged(i);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? context.colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: selected ? AppShadows.card : null,
                ),
                child: Text(
                  labels[i],
                  style: AppTypography.bodyMedium(context).copyWith(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? (activeLabelColor ?? context.colors.primaryOnSurface)
                        : context.colors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
