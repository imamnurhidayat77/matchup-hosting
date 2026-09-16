import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/tour_step.dart';
import 'spotlight_painter.dart';

/// Full-screen spotlight: a dimmed scrim with a cut-out around [holeRect],
/// plus [child] (the callout card) positioned just outside the cut-out.
///
/// Pure widget — no `OverlayEntry`, no `Ref`, no persistence. [TourHost] is
/// the only thing that decides *when* to insert this into an `Overlay`;
/// this widget only knows how to render a given (hole, callout) pair, which
/// is what makes it testable by pumping it directly with a hardcoded
/// [holeRect].
class SpotlightOverlay extends StatelessWidget {
  const SpotlightOverlay({
    super.key,
    required this.holeRect,
    required this.shape,
    required this.holeRadius,
    required this.child,
    required this.onTapScrim,
    this.scrimColor,
  });

  /// `null` → no cut-out, scrim only, callout centered on screen (the
  /// "welcome" step).
  final Rect? holeRect;
  final TourSpotlightShape shape;
  final double holeRadius;

  /// The callout card. Already-built so this widget doesn't need to know
  /// about [TourStep] copy — just where to place it.
  final Widget child;

  /// Invoked when the user taps the dimmed scrim area OUTSIDE the hole
  /// and the callout. Wired to `skip()` by [TourHost].
  final VoidCallback onTapScrim;

  /// Overrides the scrim fill. Null keeps the legacy light scrim
  /// ([AppColors.scrimIllustration]) — callers pass a theme-aware value
  /// for dark mode.
  final Color? scrimColor;

  static const double _gap = AppSpacing.x3;
  static const double _edgeInset = AppSpacing.x4;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final safePadding = MediaQuery.of(context).padding;

    return Stack(
      children: [
        // Scrim + cut-out. Tapping it skips the tour — EXCEPT inside the
        // "hole", where a transparent absorber below swallows the tap as
        // a no-op (tapping the spotlighted control itself must not skip
        // the tour out from under the user). The hole is only a hole in
        // the *painted* scrim, drawn by CustomPaint; there is no separate
        // widget or hit-test target underneath it that a tap could fall
        // through to, hence the explicit absorber.
        // This `HitTestBehavior.opaque` `GestureDetector`, filling the
        // whole screen, is what makes plan §7's "tap tembus scrim" risk a
        // non-issue: nothing below this Positioned.fill in the widget tree
        // — i.e. the actual app content this OverlayEntry sits on top of —
        // can ever receive a pointer event while the tour is active,
        // including during Discovery's 420ms post-swipe navigation delay.
        // No additional AbsorbPointer is needed on top of this.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapScrim,
            child: CustomPaint(
              painter: SpotlightPainter(
                holeRect: holeRect,
                shape: shape,
                holeRadius: holeRadius,
                scrimColor: scrimColor ?? AppColors.scrimIllustration,
              ),
            ),
          ),
        ),

        // No-op absorber over the spotlighted control: taps inside the
        // hole land here (topmost hit target) and do nothing, so they
        // neither skip the tour nor reach the app beneath. Must sit
        // ABOVE the scrim detector but BELOW the callout so Skip/Next
        // keep working.
        if (holeRect != null)
          Positioned.fromRect(
            rect: holeRect!,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),

        // Callout, positioned relative to the hole (or centered if none).
        if (holeRect == null)
          Center(child: child)
        else
          _PositionedCallout(
            holeRect: holeRect!,
            screenSize: size,
            safePadding: safePadding,
            gap: _gap,
            edgeInset: _edgeInset,
            child: child,
          ),
      ],
    );
  }
}

/// Lays the callout out below the hole if there's room, above it otherwise,
/// and clamps horizontally so it never runs past the screen edges.
class _PositionedCallout extends StatelessWidget {
  const _PositionedCallout({
    required this.holeRect,
    required this.screenSize,
    required this.safePadding,
    required this.gap,
    required this.edgeInset,
    required this.child,
  });

  final Rect holeRect;
  final Size screenSize;
  final EdgeInsets safePadding;
  final double gap;
  final double edgeInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxCalloutWidth = screenSize.width - edgeInset * 2;
    final spaceBelow = screenSize.height - safePadding.bottom - holeRect.bottom;
    final spaceAbove = holeRect.top - safePadding.top;

    // Prefer below; flip above only if below genuinely doesn't fit. 160 is
    // a conservative estimate of the callout's height before it's laid out
    // — LayoutBuilder below gets the real answer, this just picks a side.
    final placeBelow = spaceBelow >= 160 || spaceBelow >= spaceAbove;

    return Positioned(
      left: edgeInset,
      right: edgeInset,
      top: placeBelow ? holeRect.bottom + gap : null,
      bottom: placeBelow
          ? null
          : screenSize.height - holeRect.top + gap,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxCalloutWidth),
          child: child,
        ),
      ),
    );
  }
}
