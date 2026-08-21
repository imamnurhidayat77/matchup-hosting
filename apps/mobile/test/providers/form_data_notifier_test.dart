import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchup_mobile/features/activities/presentation/create/providers/form_data_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  // Convenience helpers — called as functions (not getters) inside tests
  ActivityFormData state() => container.read(formDataProvider);
  FormDataNotifier notifier() => container.read(formDataProvider.notifier);

  group('FormDataNotifier', () {
    test('should initialise with default values', () {
      expect(state().title, '');
      expect(state().location, '');
      expect(state().sportType, 'Basketball');
      expect(state().maxParticipants, 10);
      expect(state().feeType, 0);
      expect(state().skillLevel, 'Intermediate');
    });

    test('should update title via setTitle', () {
      notifier().setTitle('Evening Tennis');
      expect(state().title, 'Evening Tennis');
    });

    test('should update location via setLocation', () {
      notifier().setLocation('Central Park');
      expect(state().location, 'Central Park');
    });

    test('should update sportType via setSportType', () {
      notifier().setSportType('Tennis');
      expect(state().sportType, 'Tennis');
    });

    test('should update maxParticipants via setMaxParticipants', () {
      notifier().setMaxParticipants(20);
      expect(state().maxParticipants, 20);
    });

    test('should update skillLevel via setSkillLevel', () {
      notifier().setSkillLevel('Advanced');
      expect(state().skillLevel, 'Advanced');
    });

    test('should update feeType via setFeeType', () {
      notifier().setFeeType(1);
      expect(state().feeType, 1);
    });

    test('should update price via setPrice', () {
      notifier().setPrice('12.50');
      expect(state().price, '12.50');
    });

    test('should update selectedDate via setSelectedDate', () {
      final date = DateTime(2027, 3, 15, 14, 0);
      notifier().setSelectedDate(date);
      expect(state().selectedDate, date);
    });

    test('should update coverImage via setCoverImage', () {
      notifier().setCoverImage('base64string==');
      expect(state().coverImageBase64, 'base64string==');
    });

    test('should default durationMinutes to 120', () {
      expect(state().durationMinutes, 120);
    });

    test('should update durationMinutes via setDurationMinutes', () {
      notifier().setDurationMinutes(90);
      expect(state().durationMinutes, 90);
    });

    test('should reset all fields to defaults via reset', () {
      notifier().setTitle('Something');
      notifier().setLocation('Somewhere');
      notifier().reset();
      expect(state().title, '');
      expect(state().location, '');
    });

    test('should expose current state via getter without accessing .state', () {
      notifier().setTitle('My Activity');
      expect(notifier().current.title, 'My Activity');
    });

    test('should restore from JSON via loadFromJson', () {
      final json = {
        'title': 'Restored',
        'sportType': 'Soccer',
        'location': 'Test Loc',
        'description': '',
        'maxParticipants': 8,
        'skillLevel': 'Beginner',
        'feeType': 0,
      };
      notifier().loadFromJson(json);
      expect(state().title, 'Restored');
      expect(state().sportType, 'Soccer');
    });
  });

  group('formErrorsProvider', () {
    test(
      'should return title error when title is empty AND field is dirty',
      () {
        // Mark title as dirty first — errors only surface for touched fields
        container.read(formDirtyFieldsProvider.notifier).markDirty('title');
        final errors = container.read(formErrorsProvider);
        expect(errors, contains('title'));
      },
    );

    test(
      'should NOT return title error when title is empty but field is not dirty',
      () {
        // Default: no dirty fields — errors should not surface yet
        final errors = container.read(formErrorsProvider);
        expect(errors.containsKey('title'), isFalse);
      },
    );

    test('should clear title error once valid fields are set (dirty)', () {
      container.read(formDirtyFieldsProvider.notifier).markDirty('title');
      notifier().setTitle('Basketball Run');
      notifier().setLocation('Park');
      notifier().setSelectedDate(DateTime.now().add(const Duration(days: 1)));
      final errors = container.read(formErrorsProvider);
      expect(errors.containsKey('title'), isFalse);
    });
  });

  group('allFormErrorsProvider', () {
    test(
      'should return title error when title is empty regardless of dirty state',
      () {
        // allFormErrorsProvider is unfiltered — always reflects true validation state
        final errors = container.read(allFormErrorsProvider);
        expect(errors, contains('title'));
      },
    );
  });
}
