import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Visual state enum + resolver
// ─────────────────────────────────────────────────────────────────────────────

enum WizardFieldVisualState { idle, filled, focused, error, disabled }

WizardFieldVisualState resolveVisualState({
  required bool enabled,
  required bool hasError,
  required bool isFocused,
  required bool isFilled,
}) {
  if (!enabled) return WizardFieldVisualState.disabled;
  if (hasError) return WizardFieldVisualState.error;
  if (isFocused) return WizardFieldVisualState.focused;
  if (isFilled) return WizardFieldVisualState.filled;
  return WizardFieldVisualState.idle;
}

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens for fields
// ─────────────────────────────────────────────────────────────────────────────

const double _kFieldRadius = AppRadius.sm; // 10 — clean rect, not a pill
const double _kAreaRadius  = AppRadius.sm; // same for consistency

// ─────────────────────────────────────────────────────────────────────────────
// _WizardInputShell — decoration only, no padding, no alignment override
// ─────────────────────────────────────────────────────────────────────────────

/// Animated border + fill shell. Uses [AnimatedContainer] for single-line
/// fields (where height is fixed). For textarea, use [_WizardAreaShell]
/// which does not force any alignment.
class _WizardInputShell extends StatelessWidget {
  const _WizardInputShell({
    required this.state,
    required this.borderRadius,
    required this.child,
  });

  final WizardFieldVisualState state;
  final double borderRadius;
  final Widget child;

  Color get _borderColor => switch (state) {
        WizardFieldVisualState.focused  => AppColors.primary,
        WizardFieldVisualState.error    => AppColors.danger,
        WizardFieldVisualState.filled   => AppColors.border,
        WizardFieldVisualState.disabled => AppColors.border,
        WizardFieldVisualState.idle     => AppColors.borderInput,
      };

  double get _borderWidth =>
      (state == WizardFieldVisualState.focused ||
              state == WizardFieldVisualState.error)
          ? 1.5
          : 1.0;

  // Inactive fields use a subtle gray fill so each reads as a distinct "well"
  // even on a white page; focused field turns white to pop.
  Color get _fill => state == WizardFieldVisualState.focused
      ? AppColors.surface
      : AppColors.surfaceSubtle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.base,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _borderColor, width: _borderWidth),
      ),
      child: child,
    );
  }
}

/// Non-animated decoration shell for textarea — avoids AnimatedContainer's
/// implicit center-alignment which breaks textAlignVertical.top in multiline
/// TextFields. Uses plain [DecoratedBox] which has no alignment behaviour.
class _WizardAreaShell extends StatelessWidget {
  const _WizardAreaShell({
    required this.state,
    required this.borderRadius,
    required this.child,
  });

  final WizardFieldVisualState state;
  final double borderRadius;
  final Widget child;

  Color get _borderColor => switch (state) {
        WizardFieldVisualState.focused  => AppColors.primary,
        WizardFieldVisualState.error    => AppColors.danger,
        WizardFieldVisualState.filled   => AppColors.border,
        WizardFieldVisualState.disabled => AppColors.border,
        WizardFieldVisualState.idle     => AppColors.borderInput,
      };

  double get _borderWidth =>
      (state == WizardFieldVisualState.focused ||
              state == WizardFieldVisualState.error)
          ? 1.5
          : 1.0;

  Color get _fill => state == WizardFieldVisualState.focused
      ? AppColors.surface
      : AppColors.surfaceSubtle;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: _borderColor),
      duration: AppDurations.base,
      builder: (context, color, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: color ?? _borderColor,
              width: _borderWidth,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WizardFocusStateMixin
// ─────────────────────────────────────────────────────────────────────────────

mixin _WizardFocusStateMixin<T extends StatefulWidget> on State<T> {
  late final FocusNode focusNode = FocusNode()..addListener(_onFocusChanged);
  bool isFocused = false;

  void _onFocusChanged() {
    if (focusNode.hasFocus != isFocused) {
      setState(() => isFocused = focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

TextStyle _valueStyle() => AppTypography.bodyMedium.copyWith(
      fontSize: 15,
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w500,
    );

// Single-line bare decoration — padding via shell outer padding.
InputDecoration _singleLineDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textTertiary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );

// Textarea decoration — contentPadding owns ALL insets so cursor stays top-left.
InputDecoration _areaDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textTertiary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      isDense: false,
      // contentPadding controls top-left alignment of both hint and cursor.
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      counterText: '',
    );

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WizardFieldError extends StatelessWidget {
  const _WizardFieldError(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.bodySmall
          .copyWith(color: AppColors.danger, fontSize: 12),
    );
  }
}

class _WizardCharCounter extends StatelessWidget {
  const _WizardCharCounter({required this.length, required this.maxLength});
  final int length;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final over = length > maxLength;
    return Text(
      '$length/$maxLength',
      style: AppTypography.bodySmall.copyWith(
        fontSize: 12,
        color: over ? AppColors.danger : AppColors.textTertiary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WizardFieldLabel
// ─────────────────────────────────────────────────────────────────────────────

/// Label stays `textLabel` colour in all states except error.
/// Only the border — not the label — signals focus (modern pattern).
class WizardFieldLabel extends StatelessWidget {
  const WizardFieldLabel(
    this.text, {
    super.key,
    this.state = WizardFieldVisualState.idle,
  });

  final String text;
  final WizardFieldVisualState state;

  Color get _color => state == WizardFieldVisualState.error
      ? AppColors.danger
      : state == WizardFieldVisualState.disabled
          ? AppColors.textTertiary
          : AppColors.textLabel;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.inputLabelSmall.copyWith(color: _color),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WizardTextField — single-line
// ─────────────────────────────────────────────────────────────────────────────

class WizardTextField extends StatefulWidget {
  const WizardTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.errorText,
    this.leadingIcon,
    this.prefixText,
    this.keyboardType,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final IconData? leadingIcon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<WizardTextField> createState() => _WizardTextFieldState();
}

class _WizardTextFieldState extends State<WizardTextField>
    with _WizardFocusStateMixin {
  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final vs = resolveVisualState(
      enabled: widget.enabled,
      hasError: hasError,
      isFocused: isFocused,
      isFilled: widget.controller.text.isNotEmpty,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        WizardFieldLabel(widget.label, state: vs),
        const SizedBox(height: AppSpacing.x2),
        _WizardInputShell(
          state: vs,
          borderRadius: _kFieldRadius,
          // Shell owns layout; TextField has zero contentPadding.
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.leadingIcon != null) ...[
                  Icon(widget.leadingIcon,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.x3),
                ],
                if (widget.prefixText != null) ...[
                  Text(widget.prefixText!, style: _valueStyle()),
                  const SizedBox(width: AppSpacing.x1),
                ],
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: focusNode,
                    enabled: widget.enabled,
                    onChanged: widget.onChanged,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    onSubmitted: widget.onSubmitted,
                    cursorColor: AppColors.primary,
                    style: _valueStyle(),
                    decoration: _singleLineDecoration(widget.hint),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.x1),
          _WizardFieldError(widget.errorText!),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WizardTextArea — multi-line, cursor always top-left
// ─────────────────────────────────────────────────────────────────────────────

/// Multi-line input where contentPadding (not shell padding) owns all insets
/// so that the cursor and hint text always appear at the top-left corner.
class WizardTextArea extends StatefulWidget {
  const WizardTextArea({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.errorText,
    this.minLines = 4,
    this.maxLines = 6,
    this.maxLength,
    this.enforceMaxLength = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final bool enforceMaxLength;
  final bool enabled;

  @override
  State<WizardTextArea> createState() => _WizardTextAreaState();
}

class _WizardTextAreaState extends State<WizardTextArea>
    with _WizardFocusStateMixin {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final vs = resolveVisualState(
      enabled: widget.enabled,
      hasError: hasError,
      isFocused: isFocused,
      isFilled: widget.controller.text.isNotEmpty,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        WizardFieldLabel(widget.label, state: vs),
        const SizedBox(height: AppSpacing.x2),
        // Shell has no padding — TextField's contentPadding owns all insets.
        // Uses _WizardAreaShell (not AnimatedContainer) so textAlignVertical.top
        // works correctly — AnimatedContainer has implicit center-alignment that
        // breaks multiline TextField top-alignment.
        _WizardAreaShell(
          state: vs,
          borderRadius: _kAreaRadius,
          child: TextField(
            controller: widget.controller,
            focusNode: focusNode,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            maxLength: widget.enforceMaxLength ? widget.maxLength : null,
            textAlignVertical: TextAlignVertical.top,
            cursorColor: AppColors.primary,
            style: _valueStyle(),
            // contentPadding provides the visual inset AND aligns cursor top.
            decoration: _areaDecoration(widget.hint),
          ),
        ),
        if (hasError || widget.maxLength != null) ...[
          const SizedBox(height: AppSpacing.x1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasError)
                Expanded(child: _WizardFieldError(widget.errorText!))
              else
                const Spacer(),
              if (widget.maxLength != null)
                _WizardCharCounter(
                  length: widget.controller.text.length,
                  maxLength: widget.maxLength!,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WizardSelectField
// ─────────────────────────────────────────────────────────────────────────────

class WizardSelectField extends StatelessWidget {
  const WizardSelectField({
    super.key,
    required this.value,
    required this.onTap,
    this.placeholder,
    this.leadingIcon,
    this.hasError = false,
    this.enabled = true,
  });

  final String value;
  final VoidCallback onTap;
  final String? placeholder;
  final IconData? leadingIcon;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = value.isEmpty && placeholder != null;
    final vs = resolveVisualState(
      enabled: enabled,
      hasError: hasError,
      isFocused: false,
      isFilled: !isPlaceholder && value.isNotEmpty,
    );

    return Semantics(
      button: true,
      label: value.isEmpty ? placeholder : value,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: _WizardInputShell(
          state: vs,
          borderRadius: _kFieldRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x3,
            ),
            child: Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(leadingIcon, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.x3),
                ],
                Expanded(
                  child: Text(
                    isPlaceholder ? placeholder! : value,
                    style: _valueStyle().copyWith(
                      color: isPlaceholder
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
