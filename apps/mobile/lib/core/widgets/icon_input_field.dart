import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/dark_colors.dart';
import 'pressable_scale.dart';

/// Icon-prefixed text input matching Figma signin/signup (12px radius, 1px
/// border, 16px horizontal padding, 12px vertical padding, optional trailing
/// action like eye toggle).
class IconInputField extends StatelessWidget {
  const IconInputField({
    super.key,
    required this.label,
    required this.hint,
    this.leadingIcon,
    this.trailing,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final String? leadingIcon;
  final Widget? trailing;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.inputLabel(context)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style: AppTypography.bodyLarge(
            context,
          ).copyWith(fontSize: 15, color: context.colors.textPrimary),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppTypography.bodyFormSecondary(context),
            filled: true,
            fillColor: context.colors.surfaceSubtle,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: _border(context.colors.border),
            enabledBorder: _border(context.colors.border),
            focusedBorder: _border(AppColors.primary, width: 1.5),
            errorBorder: _border(AppColors.error),
            focusedErrorBorder: _border(AppColors.error, width: 1.5),
            prefixIcon: leadingIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: SvgPicture.asset(
                        leadingIcon!,
                        colorFilter: ColorFilter.mode(
                          context.colors.textSecondary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 52,
              minHeight: 20,
            ),
            suffixIcon: trailing == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: SizedBox(width: 20, height: 20, child: trailing),
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 52,
              minHeight: 20,
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.pillR,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Trailing eye toggle for password fields.
class PasswordToggle extends StatelessWidget {
  const PasswordToggle({super.key, required this.obscure, required this.onTap});

  final bool obscure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obscure ? 'Show password' : 'Hide password',
      child: PressableScale(
        onTap: onTap,
        child: SvgPicture.asset(
          'assets/images/auth/eye.svg',
          colorFilter: ColorFilter.mode(
            context.colors.textSecondary,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// Inline "OR" divider matching Figma — thin line + label + thin line.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.colors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTypography.bodyMedium(context).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.colors.border, height: 1)),
      ],
    );
  }
}
