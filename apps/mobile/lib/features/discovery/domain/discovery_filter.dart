/// User-configurable filter for the discovery feed. Sent to the
/// backend as a single query string and parsed in `activities.controller.ts`.
///
/// Kept tiny on purpose: every field has to map to a query parameter the
/// backend understands, and every value has to survive a JSON round trip
/// through `go_router`.
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:intl/intl.dart';

import '../../activities/domain/activity_model.dart';

class DiscoveryFilter {
    const DiscoveryFilter({
        this.sportSkills = const [],
        this.datePreset = DiscoveryDatePreset.anyTime,
        this.startAfter,
        this.startBefore,
        this.maxDistanceKm,
        this.includeSwiped = false,
    });

    /// Selected sports with their per-sport skill level. Empty = no
    /// sport filter (the backend still returns everything, just ranked
    /// without a sport preference bonus).
    final List<DiscoverySportSkill> sportSkills;

    /// Coarse "when" selector — translated to a `startAfter` /
    /// `startBefore` range before going over the wire.
    final DiscoveryDatePreset datePreset;

    /// ISO lower bound on activity start time. Overrides [datePreset]
    /// when both are set so the custom date range picker wins.
    final DateTime? startAfter;
    final DateTime? startBefore;

    /// Max distance from the device in kilometres. Null = no limit.
    final double? maxDistanceKm;

    /// "Start over" escape hatch: re-deal cards the viewer already
    /// swiped. Deliberately NOT part of [isEmpty] or [describe] — it is
    /// session UI state (driven by `_includeSwipedProvider`), not a user
    /// filter choice, and must survive independently of it.
    final bool includeSwiped;

    /// True when no filter fields are set — the wire request collapses
    /// to the bare feed path so the backend skips the discover pipeline.
    bool get isEmpty =>
        sportSkills.isEmpty &&
        datePreset == DiscoveryDatePreset.anyTime &&
        startAfter == null &&
        startBefore == null &&
        maxDistanceKm == null;

    /// Wire format for `?sportFilters=Basketball:intermediate,...`. The
    /// backend parser is the source of truth.
    String? get sportFiltersQueryParam {
        if (sportSkills.isEmpty) return null;
        return sportSkills
            .map((s) => '${Uri.encodeComponent(s.sport)}:'
                '${Uri.encodeComponent(s.skill.wireValue)}')
            .join(',');
    }

    /// ISO pairs the backend can parse directly.
    ({ String? startAfter, String? startBefore }) get dateRange {
        if (startAfter != null || startBefore != null) {
            return (
                startAfter: startAfter?.toUtc().toIso8601String(),
                startBefore: startBefore?.toUtc().toIso8601String(),
            );
        }
        switch (datePreset) {
            case DiscoveryDatePreset.anyTime:
                return (startAfter: null, startBefore: null);
            case DiscoveryDatePreset.today:
                return (
                    startAfter: _isoStartOfDay(DateTime.now()),
                    startBefore: _isoEndOfDay(DateTime.now()),
                );
            case DiscoveryDatePreset.tomorrow:
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                return (
                    startAfter: _isoStartOfDay(tomorrow),
                    startBefore: _isoEndOfDay(tomorrow),
                );
            case DiscoveryDatePreset.thisWeekend: {
                final now = DateTime.now();
                final daysToSat = (DateTime.saturday - now.weekday) % 7;
                final sat = DateTime(now.year, now.month, now.day + daysToSat);
                final sun = sat.add(const Duration(days: 1));
                return (
                    startAfter: _isoStartOfDay(sat),
                    startBefore: _isoEndOfDay(sun),
                );
            }
            case DiscoveryDatePreset.thisWeek: {
                final now = DateTime.now();
                final daysToMon = (DateTime.monday - now.weekday + 7) % 7;
                final mon = DateTime(now.year, now.month, now.day + daysToMon);
                final sun = mon.add(const Duration(days: 6));
                return (
                    startAfter: _isoStartOfDay(mon),
                    startBefore: _isoEndOfDay(sun),
                );
            }
        }
    }

    /// Maps the slider's `Today / Tomorrow / Weekend / This Week` chips
    /// to ISO bounds. Mirrors the controller's parse logic so the chip
    /// labels and the actual query stay in sync.
    static String _isoStartOfDay(DateTime d) =>
        DateTime(d.year, d.month, d.day).toUtc().toIso8601String();
    static String _isoEndOfDay(DateTime d) =>
        DateTime(d.year, d.month, d.day, 23, 59, 59, 999)
            .toUtc()
            .toIso8601String();

    /// `copyWith` can't clear a nullable field with `null` (null means
    /// "keep"), so [clearDates] resets `startAfter`/`startBefore` and
    /// the preset back to [DiscoveryDatePreset.anyTime], and
    /// [clearDistance] resets `maxDistanceKm` to null. Explicitly
    /// passed values always win over either flag.
    DiscoveryFilter copyWith({
        List<DiscoverySportSkill>? sportSkills,
        DiscoveryDatePreset? datePreset,
        DateTime? startAfter,
        DateTime? startBefore,
        double? maxDistanceKm,
        bool? includeSwiped,
        bool clearDates = false,
        bool clearDistance = false,
    }) {
        return DiscoveryFilter(
            sportSkills: sportSkills ?? this.sportSkills,
            datePreset: datePreset ??
                (clearDates ? DiscoveryDatePreset.anyTime : this.datePreset),
            startAfter: startAfter ?? (clearDates ? null : this.startAfter),
            startBefore: startBefore ?? (clearDates ? null : this.startBefore),
            maxDistanceKm:
                maxDistanceKm ?? (clearDistance ? null : this.maxDistanceKm),
            includeSwiped: includeSwiped ?? this.includeSwiped,
        );
    }

    // Value equality: the discovery listener (`prev == next`) and
    // mock verifications both rely on it. `includeSwiped` participates
    // so "Start over" writes are observable downstream.
    @override
    bool operator ==(Object other) =>
        identical(this, other) ||
        other is DiscoveryFilter &&
            listEquals(other.sportSkills, sportSkills) &&
            other.datePreset == datePreset &&
            other.startAfter == startAfter &&
            other.startBefore == startBefore &&
            other.maxDistanceKm == maxDistanceKm &&
            other.includeSwiped == includeSwiped;

    @override
    int get hashCode => Object.hash(
          Object.hashAll(sportSkills),
          datePreset,
          startAfter,
          startBefore,
          maxDistanceKm,
          includeSwiped,
        );

    /// Human-readable summary for empty states and headers, e.g.
    /// "Basketball, Tennis · Today · Within 5 km". Empty string when
    /// no filter is set.
    String describe() {
        final parts = <String>[];
        if (sportSkills.isNotEmpty) {
            parts.add(sportSkills.map((s) => s.sport).join(', '));
        }
        if (startAfter != null && startBefore != null) {
            final fmt = DateFormat('d MMM');
            parts.add('${fmt.format(startAfter!)} – ${fmt.format(startBefore!)}');
        } else if (datePreset != DiscoveryDatePreset.anyTime) {
            parts.add(datePreset.label);
        }
        if (maxDistanceKm != null) {
            parts.add('Within ${maxDistanceKm!.round()} km');
        }
        return parts.join(' · ');
    }

    /// JSON round trip for persistence (SharedPreferences). `includeSwiped`
    /// is deliberately EXCLUDED — it is session UI state ("Start over"),
    /// not a user filter choice, and must not survive restart.
    Map<String, dynamic> toJson() => {
        'sportSkills': [
            for (final s in sportSkills)
                {'sport': s.sport, 'skill': s.skill.wireValue},
        ],
        'datePreset': datePreset.name,
        if (startAfter != null)
            'startAfter': startAfter!.toIso8601String(),
        if (startBefore != null)
            'startBefore': startBefore!.toIso8601String(),
        if (maxDistanceKm != null) 'maxDistanceKm': maxDistanceKm,
    };

    factory DiscoveryFilter.fromJson(Map<String, dynamic> json) {
        DiscoveryDatePreset preset = DiscoveryDatePreset.anyTime;
        final rawPreset = json['datePreset'] as String?;
        if (rawPreset != null) {
            for (final p in DiscoveryDatePreset.values) {
                if (p.name == rawPreset) {
                    preset = p;
                    break;
                }
            }
        }
        DateTime? parseDate(Object? v) =>
            v is String ? DateTime.tryParse(v) : null;
        DiscoverySkillLevel parseSkill(Object? v) {
            for (final l in DiscoverySkillLevel.values) {
                if (l.wireValue == v) return l;
            }
            return DiscoverySkillLevel.any;
        }
        final rawSports = json['sportSkills'];
        return DiscoveryFilter(
            sportSkills: [
                if (rawSports is List)
                    for (final e in rawSports)
                        if (e is Map &&
                            (e['sport'] is String) &&
                            ((e['sport'] as String).isNotEmpty))
                            DiscoverySportSkill(
                                sport: e['sport'] as String,
                                skill: parseSkill(e['skill']),
                            ),
            ],
            datePreset: preset,
            startAfter: parseDate(json['startAfter']),
            startBefore: parseDate(json['startBefore']),
            maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble(),
        );
    }
}

/// One row in the "Your sports" section. Tapping the sport pill toggles
/// inclusion; tapping the skill row cycles the level.
class DiscoverySportSkill {
    const DiscoverySportSkill({required this.sport, required this.skill});

    final String sport;
    final DiscoverySkillLevel skill;

    DiscoverySportSkill copyWithSkill(DiscoverySkillLevel level) =>
        DiscoverySportSkill(sport: sport, skill: level);

    @override
    bool operator ==(Object other) =>
        identical(this, other) ||
        other is DiscoverySportSkill &&
            other.sport == sport &&
            other.skill == skill;

    @override
    int get hashCode => Object.hash(sport, skill);
}

/// Mirrors the backend enum so the wire format stays in lockstep.
enum DiscoverySkillLevel {
    any('any'),
    beginner('beginner'),
    intermediate('intermediate'),
    advanced('advanced');

    const DiscoverySkillLevel(this.wireValue);
    final String wireValue;
}

enum DiscoveryDatePreset { anyTime, today, tomorrow, thisWeekend, thisWeek }

extension DiscoveryDatePresetLabel on DiscoveryDatePreset {
    String get label {
        switch (this) {
            case DiscoveryDatePreset.anyTime:
                return 'Any time';
            case DiscoveryDatePreset.today:
                return 'Today';
            case DiscoveryDatePreset.tomorrow:
                return 'Tomorrow';
            case DiscoveryDatePreset.thisWeekend:
                return 'This Weekend';
            case DiscoveryDatePreset.thisWeek:
                return 'This Week';
        }
    }
}

// Re-export so test files don't need to dig into the model.
typedef ActivityWithHostContext = ActivityModel;
