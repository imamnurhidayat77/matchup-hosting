/// Admin-managed master sports entry (`GET /api/public/sports`).
///
/// Drives which sports appear on each surface: onboarding
/// ([showInOnboarding]), the discovery filter ([showInFilter]), and the
/// create/edit forms ([canHost]). Disabled sports never reach clients.
class SportConfig {
  const SportConfig({
    required this.id,
    required this.name,
    required this.emoji,
    required this.showInFilter,
    required this.showInOnboarding,
    required this.canHost,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String emoji;
  final bool showInFilter;
  final bool showInOnboarding;
  final bool canHost;
  final int sortOrder;

  static bool _flag(Object? raw) => raw == true;

  factory SportConfig.fromJson(Map<String, dynamic> json) => SportConfig(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '',
    showInFilter: _flag(json['showInFilter']),
    showInOnboarding: _flag(json['showInOnboarding']),
    canHost: _flag(json['canHost']),
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 999,
  );
}

/// Picks display names for a surface, falling back to the screen's
/// bundled list when the server config is empty or selects nothing.
/// A failed fetch must never empty a picker.
List<String> pickSportNames(
  List<SportConfig> configs,
  bool Function(SportConfig) select,
  List<String> fallback,
) {
  if (configs.isEmpty) return fallback;
  final names = configs.where(select).map((s) => s.name).toList();
  return names.isEmpty ? fallback : names;
}
