import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';

/// Feedback style for [AppTappable].
enum AppTapFeedback {
  /// Material ripple via [InkWell]. Best for surfaces with a defined fill
  /// (chips, list rows, cards that are not already an [AppCard]).
  ripple,

  /// Scale-down-on-press via [AnimatedScale]. Best for icon buttons and
  /// controls with no fill of their own — a ripple would look like a stray
  /// circle floating in empty space.
  scale,
}

/// Wraps any child with real press feedback and a guaranteed minimum hit
/// area, without changing its visual size.
///
/// Before this widget, most tappable surfaces in the app were bare
/// `GestureDetector`s — no ripple, no pressed state, nothing to confirm a tap
/// landed (PRD Section 1.4). Every icon button, chip, and custom control
/// should use [AppTappable] instead of `GestureDetector` directly.
///
/// The 44×44 minimum hit area (Apple HIG / Material accessibility guidance)
/// is enforced via a [SizedBox] + [Center] so the *visual* size of [child]
/// never changes — this is the same pattern already used for the hero
/// back/share buttons and the create-screen stepper, generalised here so
/// every new control gets it automatically instead of by convention.
///
/// ```dart
/// AppTappable(
///   onTap: _toggleFavorite,
///   semanticLabel: 'Add to favorites',
///   feedback: AppTapFeedback.scale,
///   child: Icon(Icons.favorite_border, size: 20),
/// )
/// ```
class AppTappable extends StatefulWidget {
  const AppTappable({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.onTap,
    this.feedback = AppTapFeedback.ripple,
    this.minSize = 44,
    this.borderRadius,
    this.enabled = true,
    this.haptic = true,
  });

  final Widget child;

  /// Required — every tappable surface must be identifiable to a screen
  /// reader. See PRD Section 2.1 principle 6 and Appendix C.2.
  final String semanticLabel;

  final VoidCallback? onTap;
  final AppTapFeedback feedback;

  /// Minimum hit area edge length. Defaults to the 44pt accessibility floor;
  /// only raise it, never lower it.
  final double minSize;

  /// [AppTapFeedback.ripple] only — clip/ripple radius. Defaults to
  /// [AppRadius.md] if unset.
  final double? borderRadius;

  final bool enabled;

  /// Light haptic tap on press, matching the rest of the app's buttons.
  final bool haptic;

  @override
  State<AppTappable> createState() => _AppTappableState();
}

class _AppTappableState extends State<AppTappable> {
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  void _handleTap() {
    if (!_interactive) return;
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    // Stack (not SizedBox+Center): a SizedBox forces its child's layout box
    // to exactly minSize, which *shrinks* a child larger than minSize instead
    // of leaving it alone. Stack's default sizing takes the largest
    // non-positioned child in each dimension, so the invisible spacer only
    // grows the hit area when the real child is smaller than minSize, and
    // never shrinks a child that's already bigger.
    final sized = Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(width: widget.minSize, height: widget.minSize),
        widget.child,
      ],
    );

    final content = widget.feedback == AppTapFeedback.ripple
        ? Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: _interactive ? _handleTap : null,
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? AppRadius.md,
              ),
              child: sized,
            ),
          )
        : GestureDetector(
            onTap: _interactive ? _handleTap : null,
            onTapDown: _interactive
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapUp: _interactive
                ? (_) => setState(() => _pressed = false)
                : null,
            onTapCancel: _interactive
                ? () => setState(() => _pressed = false)
                : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1.0,
              duration: AppDurations.fast,
              curve: Curves.easeOut,
              child: sized,
            ),
          );

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      enabled: _interactive,
      child: Opacity(opacity: widget.enabled ? 1.0 : 0.5, child: content),
    );
  }
}
