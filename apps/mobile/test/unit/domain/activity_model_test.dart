import 'package:flutter_test/flutter_test.dart';
import 'package:matchup_mobile/features/activities/domain/activity_model.dart';

void main() {
  group('ActivityModel', () {
    final baseJson = <String, dynamic>{
      'id': 'act-001',
      'title': 'Weekend Basketball',
      'sport_type': 'Basketball',
      'description': 'Fun pickup game',
      'location': 'Central Park',
      'distance_km': 2.5,
      'date_time': '2026-09-15T16:00:00.000Z',
      'skill_level': 'Intermediate',
      'capacity': 10,
      'participant_count': 6,
      'host_name': 'Alex',
      'cover_image_url': null,
      'status': 'available', // ActivityStatus.available
    };

    test('should deserialise correctly from JSON', () {
      final model = ActivityModel.fromJson(baseJson);

      expect(model.id, 'act-001');
      expect(model.title, 'Weekend Basketball');
      expect(model.sportType, 'Basketball');
      expect(model.distanceKm, 2.5);
      expect(model.capacity, 10);
      expect(model.participantCount, 6);
      expect(model.status, ActivityStatus.available);
    });

    test('should serialise to JSON and round-trip without data loss', () {
      final original = ActivityModel.fromJson(baseJson);
      final roundTripped = ActivityModel.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.title, original.title);
      expect(roundTripped.distanceKm, original.distanceKm);
      expect(roundTripped.status, original.status);
      expect(roundTripped.dateTime, original.dateTime);
    });

    test('should use defaults for missing optional fields', () {
      final minimal = ActivityModel.fromJson({'id': 'x'});

      expect(minimal.title, '');
      expect(minimal.capacity, 10);
      expect(minimal.status, ActivityStatus.available);
      expect(minimal.coverImageUrl, isNull);
    });

    group('isFull', () {
      test('should return true when participantCount equals capacity', () {
        final full = ActivityModel.fromJson({
          ...baseJson,
          'participant_count': 10,
          'capacity': 10,
        });
        expect(full.isFull, isTrue);
      });

      test('should return false when there are spots remaining', () {
        final notFull = ActivityModel.fromJson(baseJson);
        expect(notFull.isFull, isFalse);
      });
    });

    group('isAlmostFull', () {
      test('should return true when fill rate is at or above 80%', () {
        final almostFull = ActivityModel.fromJson({
          ...baseJson,
          'participant_count': 8,
          'capacity': 10,
        });
        expect(almostFull.isAlmostFull, isTrue);
      });

      test('should return false when fill rate is below 80%', () {
        final notAlmost = ActivityModel.fromJson({
          ...baseJson,
          'participant_count': 3,
          'capacity': 10,
        });
        expect(notAlmost.isAlmostFull, isFalse);
      });
    });

    test('should compute spotsLeft correctly', () {
      final model = ActivityModel.fromJson(baseJson);
      // capacity 10, participantCount 6
      expect(model.spotsLeft, 4);
    });

    test('should map all ActivityStatus values from JSON name', () {
      for (final status in ActivityStatus.values) {
        final json = {...baseJson, 'status': status.name};
        expect(ActivityModel.fromJson(json).status, status);
      }
    });

    group('durationMinutes / endTime', () {
      test('should default durationMinutes to 120 when absent from JSON', () {
        final model = ActivityModel.fromJson(baseJson);
        expect(model.durationMinutes, 120);
      });

      test('should read durationMinutes from JSON when present', () {
        final model = ActivityModel.fromJson({
          ...baseJson,
          'duration_minutes': 90,
        });
        expect(model.durationMinutes, 90);
      });

      test('should compute endTime as dateTime + durationMinutes', () {
        final model = ActivityModel.fromJson({
          ...baseJson,
          'date_time': '2026-09-15T16:00:00.000Z',
          'duration_minutes': 90,
        });
        expect(model.endTime, DateTime.parse('2026-09-15T17:30:00.000Z'));
      });

      test('should round-trip durationMinutes through toJson/fromJson', () {
        final original = ActivityModel.fromJson({
          ...baseJson,
          'duration_minutes': 180,
        });
        final roundTripped = ActivityModel.fromJson(original.toJson());
        expect(roundTripped.durationMinutes, 180);
      });
    });
  });
}
