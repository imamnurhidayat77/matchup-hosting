import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../providers/form_data_provider.dart';
import '../providers/wizard_controller_provider.dart';

/// Keys for Hive storage
const String _draftBoxName = 'wizard_draft';
const String _draftKey = 'create_activity';

/// Provider for draft storage
final draftStorageProvider = Provider<DraftStorage>((ref) {
  return DraftStorage();
});

/// Service for managing draft wizard data
class DraftStorage {
  late final _box = Hive.box(_draftBoxName);

  /// Save current draft
  Future<void> saveDraft(ActivityFormData formData, int step) async {
    final draft = {
      'step': step,
      'formData': formData.toJson(),
      'lastModified': DateTime.now().toIso8601String(),
    };
    await _box.put(_draftKey, draft);
  }

  /// Load saved draft
  Future<Map<String, dynamic>?> loadDraft() async {
    final draft = _box.get(_draftKey);
    return draft;
  }

  /// Clear draft
  Future<void> clearDraft() async {
    await _box.delete(_draftKey);
  }

  /// Check if draft exists
  bool hasDraft() {
    return _box.containsKey(_draftKey);
  }

  /// Get draft step
  int? getDraftStep() {
    final draft = _box.get(_draftKey);
    return draft != null ? draft['step'] as int? : null;
  }

  /// Get draft form data
  ActivityFormData? getDraftFormData() {
    final draft = _box.get(_draftKey);
    if (draft == null) return null;
    return ActivityFormData.fromJson(draft['formData'] as Map<String, dynamic>);
  }
}

/// Provider for auto-save functionality
final autoSaveProvider = Provider<AutoSave>((ref) {
  final controller = ref.read(wizardControllerProvider.notifier);
  final formDataNotifier = ref.read(formDataProvider.notifier);
  final draftStorage = ref.read(draftStorageProvider);

  return AutoSave(
    controller: controller,
    formDataNotifier: formDataNotifier,
    draftStorage: draftStorage,
  );
});

/// Auto-save manager
class AutoSave {
  final WizardControllerNotifier controller;
  final FormDataNotifier formDataNotifier;
  final DraftStorage draftStorage;

  AutoSave({
    required this.controller,
    required this.formDataNotifier,
    required this.draftStorage,
  });

  /// Initialize auto-save
  Future<void> init() async {
    // Check for existing draft
    if (draftStorage.hasDraft()) {
      final draft = await draftStorage.loadDraft();
      if (draft != null) {
        controller.setStep(draft['step'] as int? ?? 1);
        formDataNotifier.loadFromJson(
          draft['formData'] as Map<String, dynamic>,
        );
      }
    }
  }

  /// Trigger auto-save
  Future<void> save() async {
    await draftStorage.saveDraft(
      formDataNotifier.current,
      controller.currentStep,
    );
  }

  /// Clear draft on successful submission
  Future<void> clear() async {
    await draftStorage.clearDraft();
  }
}
