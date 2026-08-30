import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/dark_colors.dart';
import '../../domain/activity_model.dart';
import 'discovery_card.dart';

/// The Discovery swipe deck: drag-to-dismiss/like gesture, spring-back on a
/// sub-threshold release, LIKE/NOPE stamp fade-in past threshold, and a
/// depth-cued card stack (next card visible behind at reduced scale/opacity).
///
/// Extracted out of `discovery_screen.dart` (PRD Section 1.1) so the screen
/// itself only owns the activity list + swipe callbacks.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.activities,
    required this.topIndex,
    required this.onSwiped,
  });

  final List<ActivityModel> activities;
  final int topIndex;
  final void Function(bool liked) onSwiped;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck> with TickerProviderStateMixin {
  Offset _drag = Offset.zero;
  bool _animating = false;
  bool _thresholdReached = false;

  // Created eagerly in initState — not as lazy `late final` initializers.
  // A lazy initializer only runs on first *access*, and if a SwipeDeck is
  // disposed without ever being dragged (e.g. it's swapped out by a new
  // `ValueKey` before any gesture fires), `dispose()` itself becomes the
  // first access. That constructs an `AnimationController(vsync: this)`
  // against a State that's already deactivating, which crashes with
  // "Looking up a deactivated widget's ancestor is unsafe."
  late AnimationController _springController;
  late AnimationController _exitController;
  late Animation<Offset> _exitAnimation;
  Offset _exitStart = Offset.zero;
  Offset _exitEnd = Offset.zero;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topIndex != widget.topIndex && !_animating) {
      _drag = Offset.zero;
    }
  }

  @override
  void dispose() {
    _springController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_animating) return;
    setState(() => _drag += d.delta);
    // Subtle tick when crossing the commit threshold — confirms "release
    // now and it will count" without looking at the stamps.
    final threshold = MediaQuery.of(context).size.width * 0.25;
    final crossed = _drag.dx.abs() >= threshold;
    if (crossed && !_thresholdReached) {
      HapticFeedback.selectionClick();
      _thresholdReached = true;
    } else if (!crossed) {
      _thresholdReached = false;
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_animating) return;
    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.25;
    final vx = d.velocity.pixelsPerSecond.dx;
    final flingCommit = vx.abs() > 700 && vx.sign == _drag.dx.sign;
    if (_drag.dx > threshold || (_drag.dx > 0 && flingCommit)) {
      _animateOut(true, d.velocity.pixelsPerSecond);
    } else if (_drag.dx < -threshold || (_drag.dx < 0 && flingCommit)) {
      _animateOut(false, d.velocity.pixelsPerSecond);
    } else {
      _springBack();
    }
  }

  Future<void> _springBack() async {
    final start = _drag;
    final tween = Tween<Offset>(begin: start, end: Offset.zero);
    final animation = tween.animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutCubic),
    );
    void listener() {
      if (!mounted) return;
      setState(() => _drag = animation.value);
    }

    _springController.addListener(listener);
    setState(() => _animating = true);
    _springController.value = 0;
    await _springController.forward();
    _springController.removeListener(listener);
    if (!mounted) return;
    setState(() {
      _drag = Offset.zero;
      _animating = false;
    });
  }

  Future<void> _animateOut(bool liked, Offset flingVelocity) async {
    _exitStart = _drag;
    final width = MediaQuery.of(context).size.width;
    final travelX = liked ? width * 1.4 : -width * 1.4;
    final exitVx = flingVelocity.dx.abs();
    final exitDurationMs = (320 - (exitVx.clamp(0, 1200) / 1200) * 120).round();
    _exitEnd = Offset(travelX, _drag.dy + 80);
    _exitController.duration = Duration(milliseconds: exitDurationMs);
    final tween = Tween<Offset>(begin: _exitStart, end: _exitEnd);
    _exitAnimation = tween.animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeOutCubic),
    );
    void listener() {
      if (!mounted) return;
      setState(() => _drag = _exitAnimation.value);
    }

    _exitController.addListener(listener);
    setState(() => _animating = true);
    _exitController.value = 0;
    await _exitController.forward();
    _exitController.removeListener(listener);
    if (!mounted) return;
    setState(() {
      _drag = Offset.zero;
      _animating = false;
    });
    widget.onSwiped(liked);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.activities;
    final top = items[widget.topIndex];
    final next = items[(widget.topIndex + 1).clamp(0, items.length - 1)];
    final afterNext = items[(widget.topIndex + 2).clamp(0, items.length - 1)];

    final dragX = _drag.dx;
    final absDrag = dragX.abs();
    final progress = (absDrag / 320).clamp(0.0, 1.0);
    final rotation = dragX / 1000;
    final likeOpacity = (dragX / 120).clamp(0.0, 1.0);
    final nopeOpacity = (-dragX / 120).clamp(0.0, 1.0);

    final nextScale = lerpDouble(0.95, 1.0, progress)!;
    final nextOpacity = lerpDouble(0.85, 1.0, progress)!;
    final nextOffset = lerpDouble(16.0, 0.0, progress)!;
    final afterScale = lerpDouble(0.88, 0.95, progress)!;
    final afterOpacity = lerpDouble(0.55, 0.85, progress)!;
    final afterOffset = lerpDouble(32.0, 16.0, progress)!;

    // Each card is sized to the full deck area (via the LayoutBuilder box)
    // so the DiscoveryCard's internal Expanded hero can absorb the leftover
    // height — the card fills the deck exactly (no bottom overflow) while its
    // info block keeps its natural height (no mid-row clipping). Depth-cued
    // background cards peek out via their scale/offset.
    return LayoutBuilder(
      builder: (context, constraints) {
        final deckWidth = constraints.maxWidth;
        final deckHeight = constraints.maxHeight;
        SizedBox sized(Widget child) =>
            SizedBox(width: deckWidth, height: deckHeight, child: child);

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, afterOffset),
              child: Transform.scale(
                scale: afterScale,
                child: Opacity(
                  opacity: afterOpacity,
                  child: sized(DiscoveryCard(activity: afterNext)),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, nextOffset),
              child: Transform.scale(
                scale: nextScale,
                child: Opacity(
                  opacity: nextOpacity,
                  child: sized(DiscoveryCard(activity: next)),
                ),
              ),
            ),
            Semantics(
              label:
                  'Activity card. Swipe right to like, left to pass. '
                  'Use the action buttons below as an alternative to swiping.',
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Transform.translate(
                  offset: _drag,
                  child: Transform.rotate(
                    angle: rotation,
                    child: sized(
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          DiscoveryCard(activity: top),
                          if (likeOpacity > 0)
                            Positioned(
                              top: 28,
                              left: 28,
                              child: Opacity(
                                opacity: likeOpacity,
                                child: const _StampBadge(
                                  label: 'LIKE',
                                  color: AppColors.likeGreen,
                                  rotation: -0.2,
                                ),
                              ),
                            ),
                          if (nopeOpacity > 0)
                            Positioned(
                              top: 28,
                              right: 28,
                              child: Opacity(
                                opacity: nopeOpacity,
                                child: const _StampBadge(
                                  label: 'NOPE',
                                  color: AppColors.nopeRed,
                                  rotation: 0.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StampBadge extends StatelessWidget {
  const _StampBadge({
    required this.label,
    required this.color,
    required this.rotation,
  });

  final String label;
  final Color color;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3 + 2,
          vertical: AppSpacing.x2,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: AppRadius.xsR,
          color: context.colors.surface.withValues(alpha: 0.9),
        ),
        child: Text(
          label,
          style: AppTypography.headlineSmall(context).copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 28,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
