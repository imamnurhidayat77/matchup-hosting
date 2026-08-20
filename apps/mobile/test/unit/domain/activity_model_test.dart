import 'package:flutter_test/flutter_test.dart';
import 'package:matchup_mobile/features/activities/domain/activity_model.dart';

void main() {
  group('ActivityModel', () {
    final baseJson = <String, dynamic>{
      'id': 'act-001',
      'title': 'Weekend Basketball',
      'sportType': 'Basketball',
      'description': 'Fun pickup game',
      'location': 'Central Park',
      'distanceKm': 2.5,
      'dateTime': '2026-09-15T16:00:00.000Z',
      'skillLevel': 'Intermediate',
      'capacity': 10,
      'participantCount': 6,
      'hostName': 'Alex',
      'coverImageUrl': null,
      'status': 0, // ActivityStatus.available
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
          'participantCount': 10,
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
          'participantCount': 8,
          'capacity': 10,
        });
        expect(almostFull.isAlmostFull, isTrue);
      });

      test('should return false when fill rate is below 80%', () {
        final notAlmost = ActivityModel.fromJson({
          ...baseJson,
          'participantCount': 3,
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

    test('should map all ActivityStatus values from JSON index', () {
      for (final status in ActivityStatus.values) {
        final json = {...baseJson, 'status': status.index};
        expect(ActivityModel.fromJson(json).status, status);
      }
    });
  });
}
