import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Skill level for a single sport preference.
enum SkillLevel { beginner, intermediate, advanced }

extension SkillLevelX on SkillLevel {
  String get label => switch (this) {
    SkillLevel.beginner => 'Beginner',
    SkillLevel.intermediate => 'Intermediate',
    SkillLevel.advanced => 'Advanced',
  };

  String get short => switch (this) {
    SkillLevel.beginner => 'Bgnr',
    SkillLevel.intermediate => 'Intm',
    SkillLevel.advanced => 'Adv',
  };

  Color get color => switch (this) {
    SkillLevel.beginner => AppColors.success,
    SkillLevel.intermediate => AppColors.primary,
    SkillLevel.advanced => AppColors.warning,
  };
}

/// Price preference for the discovery feed filter.
enum PricePreference { free, paid, both }

extension PricePreferenceX on PricePreference {
  String get label => switch (this) {
    PricePreference.free => 'Free',
    PricePreference.paid => 'Paid',
    PricePreference.both => 'Both',
  };

  IconData get icon => switch (this) {
    PricePreference.free => Icons.local_offer_outlined,
    PricePreference.paid => Icons.payments_outlined,
    PricePreference.both => Icons.all_inclusive,
  };
}

/// A single sport option in the preferences grid.
class SportOption {
  const SportOption({required this.name, required this.icon});

  final String name;
  final IconData icon;
}
