import 'package:flutter/material.dart';

/// Dark theme tokens for MatchUp. Values follow standard iOS dark
/// palette conventions; tweak as Figma dark mode spec becomes available.
@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.divider,
    required this.shadow,
    required this.textPrimary,
    required this.textLabel,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnPrimary,
    required this.iconPrimary,
    required this.primaryLight,
    required this.scrim,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color divider;
  final Color shadow;
  final Color textPrimary;
  final Color textLabel;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnPrimary;
  final Color iconPrimary;
  final Color primaryLight;
  final Color scrim;

  static const light = AppColorTokens(
    background: Color(0xFFF8F9FA),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    divider: Color(0xFFE5E7EB),
    shadow: Color(0x1A000000),
    textPrimary: Color(0xFF0F172A),
    textLabel: Color(0xFF334155),
    textSecondary: Color(0xFF64748B),
    textTertiary: Color(0xFF9CA3AF),
    textOnPrimary: Color(0xFFFFFFFF),
    iconPrimary: Color(0xFF1E293B),
    primaryLight: Color(0xFFDBEAFE),
    scrim: Color(0x660F172A),
  );

  static const dark = AppColorTokens(
    background: Color(0xFF0B1220),
    surface: Color(0xFF111827),
    card: Color(0xFF1F2937),
    border: Color(0xFF334155),
    divider: Color(0xFF1F2937),
    shadow: Color(0x66000000),
    textPrimary: Color(0xFFF1F5F9),
    textLabel: Color(0xFFCBD5E1),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    textOnPrimary: Color(0xFFFFFFFF),
    iconPrimary: Color(0xFFE2E8F0),
    primaryLight: Color(0xFF1E3A8A),
    scrim: Color(0x99000000),
  );

  @override
  AppColorTokens copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? divider,
    Color? shadow,
    Color? textPrimary,
    Color? textLabel,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnPrimary,
    Color? iconPrimary,
    Color? primaryLight,
    Color? scrim,
  }) {
    return AppColorTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      shadow: shadow ?? this.shadow,
      textPrimary: textPrimary ?? this.textPrimary,
      textLabel: textLabel ?? this.textLabel,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      primaryLight: primaryLight ?? this.primaryLight,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textLabel: Color.lerp(textLabel, other.textLabel, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Convenience accessor for theme-aware tokens. Use this instead of
/// `AppColors.surface` in new code; the static `AppColors` is kept for
/// backwards compatibility with hard-coded light values.
extension AppColorTokensX on BuildContext {
  AppColorTokens get colors => Theme.of(this).extension<AppColorTokens>()!;
}
