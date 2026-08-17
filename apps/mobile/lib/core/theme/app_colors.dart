import 'package:flutter/material.dart';

/// Figma-based color palette for MatchUp.
class AppColors {
  AppColors._();

  // Primary blue (Figma: #2572E5 / #2563EB)
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryDarker = Color(0xFF145AC8); // Figma primary-dark token
  static const Color primaryLight = Color(0xFFDBEAFE);

  // Splash gradient endpoints (Figma)
  static const Color splashTop = Color(0xFF2D7FF9);
  static const Color splashBottom = Color(0xFF1A5BC4);

  // Accent orange
  static const Color accent = Color(0xFFFF6B00);
  static const Color accentLight = Color(0xFFFFE5D0);

  // Backgrounds
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color card = Colors.white;

  // Text (Figma tokens)
  static const Color textPrimary = Color(0xFF0F172A); // Figma text-primary
  static const Color textLabel = Color(0xFF334155); // Figma text-label
  static const Color textSecondary = Color(0xFF64748B); // Figma text-secondary
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);

  // UI
  static const Color border = Color(0xFFE2E8F0); // Figma border-default
  static const Color borderMuted = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x1A000000);
  static const Color iconPrimary = Color(0xFF1E293B); // Figma icon-primary (home indicator)
  static const Color scrim = Color(0x660F172A); // 40% black overlay on onboarding illustrations
}
