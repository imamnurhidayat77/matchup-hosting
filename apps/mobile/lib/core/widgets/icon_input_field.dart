import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

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
        Text(label, style: AppTypography.inputLabel),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style: AppTypography.bodyLarge.copyWith(fontSize: 15, color: AppColors.textPrimary),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppTypography.bodyFormSecondary,
            filled: true,
            fillColor: AppColors.surfaceSubtle,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary, width: 1.5),
            errorBorder: _border(AppColors.error),
            focusedErrorBorder: _border(AppColors.error, width: 1.5),
            prefixIcon: leadingIcon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: SvgPicture.asset(
                        leadingIcon!,
                        colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
                      ),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 20),
            suffixIcon: trailing == null
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: trailing,
                    ),
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 20),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(100),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Trailing eye toggle for password fields.
class PasswordToggle extends StatelessWidget {
  const PasswordToggle({
    super.key,
    required this.obscure,
    required this.onTap,
  });

  final bool obscure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: obscure ? 'Show password' : 'Hide password',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SvgPicture.asset(
          'assets/images/auth/eye.svg',
          colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
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
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}