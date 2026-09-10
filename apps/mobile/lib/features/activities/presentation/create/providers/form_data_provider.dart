import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Form data model for the wizard
class ActivityFormData {
  final String title;
  final String sportType;

  /// Local file path of the cover image picked by the user, if any.
  /// Stored as a path (not base64) so we don't blow up the form draft
  /// on every keystroke. The actual upload to Firebase Storage
  /// happens in `_submit()` and produces a public URL the backend can
  /// fetch.
  final String? coverImagePath;
  final DateTime? selectedDate;
  final String location;
  final String description;
  final int maxParticipants;
  final String skillLevel;
  final int feeType; // 0 = Free, 1 = Paid
  final String? price;

  /// How long the activity runs, in minutes. Default 120 (2h) matches the
  /// assumption the detail screen used before this field existed.
  final int durationMinutes;

  /// Who can discover and join: 'Public', 'Friends', or 'Invite only'.
  /// Captured on step 2 of the wizard and surfaced in the live preview.
  final String visibility;

  /// Backend join policy: 'open' (instant join) or 'approval' (host
  /// must approve each request). Matches `ActivityRecord.joinPolicy`.
  final String joinPolicy;

  const ActivityFormData({
    this.title = '',
    this.sportType = 'Basketball',
    this.coverImagePath,
    this.selectedDate,
    this.location = '',
    this.description = '',
    this.maxParticipants = 10,
    this.skillLevel = 'Intermediate',
    this.feeType = 0,
    this.price,
    this.durationMinutes = 120,
    this.visibility = 'Public',
    this.joinPolicy = 'open',
  });

  ActivityFormData copyWith({
    String? title,
    String? sportType,
    String? coverImagePath,
    DateTime? selectedDate,
    String? location,
    String? description,
    int? maxParticipants,
    String? skillLevel,
    int? feeType,
    String? price,
    int? durationMinutes,
    String? visibility,
    String? joinPolicy,
  }) {
    return ActivityFormData(
      title: title ?? this.title,
      sportType: sportType ?? this.sportType,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      selectedDate: selectedDate ?? this.selectedDate,
      location: location ?? this.location,
      description: description ?? this.description,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      skillLevel: skillLevel ?? this.skillLevel,
      feeType: feeType ?? this.feeType,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      visibility: visibility ?? this.visibility,
      joinPolicy: joinPolicy ?? this.joinPolicy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'sportType': sportType,
      'coverImagePath': coverImagePath,
      'selectedDate': selectedDate?.toIso8601String(),
      'location': location,
      'description': description,
      'maxParticipants': maxParticipants,
      'skillLevel': skillLevel,
      'feeType': feeType,
      'price': price,
      'durationMinutes': durationMinutes,
      'visibility': visibility,
      'joinPolicy': joinPolicy,
    };
  }

  factory ActivityFormData.fromJson(Map<String, dynamic> json) {
    return ActivityFormData(
      title: json['title'] as String? ?? '',
      sportType: json['sportType'] as String? ?? 'Basketball',
      coverImagePath: json['coverImagePath'] as String?,
      selectedDate: json['selectedDate'] != null
          ? DateTime.parse(json['selectedDate'] as String)
          : null,
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      maxParticipants: (json['maxParticipants'] as int?) ?? 10,
      skillLevel: json['skillLevel'] as String? ?? 'Intermediate',
      feeType: json['feeType'] as int? ?? 0,
      price: json['price'] as String?,
      durationMinutes: json['durationMinutes'] as int? ?? 120,
      visibility: json['visibility'] as String? ?? 'Public',
      joinPolicy: json['joinPolicy'] as String? ?? 'open',
    );
  }
}

/// Provider for form data
final formDataProvider =
    StateNotifierProvider<FormDataNotifier, ActivityFormData>((ref) {
      return FormDataNotifier();
    });

class FormDataNotifier extends StateNotifier<ActivityFormData> {
  FormDataNotifier() : super(const ActivityFormData());

  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  void setSportType(String sportType) {
    state = state.copyWith(sportType: sportType);
  }

  void setCoverImage(String? path) {
    state = state.copyWith(coverImagePath: path);
  }

  void setSelectedDate(DateTime? date) {
    state = state.copyWith(selectedDate: date);
  }

  void setLocation(String location) {
    state = state.copyWith(location: location);
  }

  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  void setMaxParticipants(int participants) {
    state = state.copyWith(maxParticipants: participants);
  }

  void setSkillLevel(String level) {
    state = state.copyWith(skillLevel: level);
  }

  void setFeeType(int type) {
    state = state.copyWith(feeType: type);
  }

  void setPrice(String? price) {
    state = state.copyWith(price: price);
  }

  void setDurationMinutes(int minutes) {
    state = state.copyWith(durationMinutes: minutes);
  }

  void setVisibility(String visibility) {
    state = state.copyWith(visibility: visibility);
  }

  void setJoinPolicy(String joinPolicy) {
    state = state.copyWith(joinPolicy: joinPolicy);
  }

  void reset() {
    state = const ActivityFormData();
  }

  /// Read current form data (for auto-save) without exposing .state.
  ActivityFormData get current => state;

  /// Restore form from saved JSON (for draft resume).
  void loadFromJson(Map<String, dynamic> json) {
    state = ActivityFormData.fromJson(json);
  }
}

/// Tracks which fields have been "touched" (user interacted or Next was pressed).
/// Errors are only shown in the UI for fields present in this set.
final formDirtyFieldsProvider =
    StateNotifierProvider<FormDirtyNotifier, Set<String>>(
      (ref) => FormDirtyNotifier(),
    );

class FormDirtyNotifier extends StateNotifier<Set<String>> {
  FormDirtyNotifier() : super(const {});

  void markDirty(String field) {
    if (!state.contains(field)) {
      state = {...state, field};
    }
  }

  /// Mark all fields for the given step as dirty (called when Next is tapped).
  void markStepDirty(int step) {
    final fields = _stepFields(step);
    if (!state.containsAll(fields)) {
      state = {...state, ...fields};
    }
  }

  void reset() => state = const {};

  static List<String> _stepFields(int step) {
    switch (step) {
      case 1:
        return ['title'];
      case 2:
        return ['location', 'selectedDate', 'maxParticipants'];
      default:
        return [];
    }
  }
}

/// All validation errors regardless of dirty state — used internally and by
/// NavigationControls to determine if the Next button should be enabled.
final allFormErrorsProvider = Provider<Map<String, String>>((ref) {
  final formData = ref.watch(formDataProvider);
  return _validate(formData);
});

/// Validation errors **filtered to dirty fields only**.
/// Widgets should watch this — it never shows errors for untouched fields.
final formErrorsProvider = Provider<Map<String, String>>((ref) {
  final all = ref.watch(allFormErrorsProvider);
  final dirty = ref.watch(formDirtyFieldsProvider);
  return {
    for (final entry in all.entries)
      if (dirty.contains(entry.key)) entry.key: entry.value,
  };
});

Map<String, String> _validate(ActivityFormData data) {
  final errors = <String, String>{};

  if (data.title.trim().isEmpty) {
    errors['title'] = 'Please enter a title';
  }

  if (data.location.trim().isEmpty) {
    errors['location'] = 'Please enter a location';
  }

  if (data.selectedDate != null &&
      data.selectedDate!.isBefore(DateTime.now())) {
    errors['selectedDate'] = 'Date must be in the future';
  }

  if (data.maxParticipants < 2) {
    errors['maxParticipants'] = 'Minimum 2 participants required';
  }

  if (data.maxParticipants > 50) {
    errors['maxParticipants'] = 'Maximum 50 participants allowed';
  }

  if (data.feeType == 1 && (data.price == null || data.price!.trim().isEmpty)) {
    errors['price'] = 'Please enter a price';
  }

  return errors;
}

/// Provider to check if the entire form is valid (used for final submit check).
final isFormValidProvider = Provider<bool>((ref) {
  final errors = ref.watch(allFormErrorsProvider);
  return errors.isEmpty;
});
