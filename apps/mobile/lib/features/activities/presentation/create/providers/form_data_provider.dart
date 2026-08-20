import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Form data model for the wizard
class ActivityFormData {
  final String title;
  final String sportType;
  final String? coverImageBase64;
  final DateTime? selectedDate;
  final String location;
  final String description;
  final int maxParticipants;
  final String skillLevel;
  final int feeType; // 0 = Free, 1 = Paid
  final String? price;

  const ActivityFormData({
    this.title = '',
    this.sportType = 'Basketball',
    this.coverImageBase64,
    this.selectedDate,
    this.location = '',
    this.description = '',
    this.maxParticipants = 10,
    this.skillLevel = 'Intermediate',
    this.feeType = 0,
    this.price,
  });

  ActivityFormData copyWith({
    String? title,
    String? sportType,
    String? coverImageBase64,
    DateTime? selectedDate,
    String? location,
    String? description,
    int? maxParticipants,
    String? skillLevel,
    int? feeType,
    String? price,
  }) {
    return ActivityFormData(
      title: title ?? this.title,
      sportType: sportType ?? this.sportType,
      coverImageBase64: coverImageBase64 ?? this.coverImageBase64,
      selectedDate: selectedDate ?? this.selectedDate,
      location: location ?? this.location,
      description: description ?? this.description,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      skillLevel: skillLevel ?? this.skillLevel,
      feeType: feeType ?? this.feeType,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'sportType': sportType,
      'coverImageBase64': coverImageBase64,
      'selectedDate': selectedDate?.toIso8601String(),
      'location': location,
      'description': description,
      'maxParticipants': maxParticipants,
      'skillLevel': skillLevel,
      'feeType': feeType,
      'price': price,
    };
  }

  factory ActivityFormData.fromJson(Map<String, dynamic> json) {
    return ActivityFormData(
      title: json['title'] as String? ?? '',
      sportType: json['sportType'] as String? ?? 'Basketball',
      coverImageBase64: json['coverImageBase64'] as String?,
      selectedDate: json['selectedDate'] != null
          ? DateTime.parse(json['selectedDate'] as String)
          : null,
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      maxParticipants: (json['maxParticipants'] as int?) ?? 10,
      skillLevel: json['skillLevel'] as String? ?? 'Intermediate',
      feeType: json['feeType'] as int? ?? 0,
      price: json['price'] as String?,
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

  void setCoverImage(String? base64) {
    state = state.copyWith(coverImageBase64: base64);
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
