import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable state for the wizard navigation.
class WizardController {
  const WizardController({
    this.currentStep = 1,
    this.completedSteps = const [],
    this.isNavigationLocked = false,
  });

  final int currentStep;
  final List<int> completedSteps;
  final bool isNavigationLocked;

  WizardController copyWith({
    int? currentStep,
    List<int>? completedSteps,
    bool? isNavigationLocked,
  }) {
    return WizardController(
      currentStep: currentStep ?? this.currentStep,
      completedSteps: completedSteps ?? this.completedSteps,
      isNavigationLocked: isNavigationLocked ?? this.isNavigationLocked,
    );
  }

  bool get isLastStep => currentStep == 3;
  bool get isFirstStep => currentStep == 1;
  bool isStepCompleted(int step) => completedSteps.contains(step);
  int get completedCount => completedSteps.length;
}

/// Provider for wizard controller
final wizardControllerProvider =
    StateNotifierProvider<WizardControllerNotifier, WizardController>(
  (ref) => WizardControllerNotifier(),
);

class WizardControllerNotifier extends StateNotifier<WizardController> {
  WizardControllerNotifier() : super(const WizardController());

  void setStep(int step) {
    if (step < 1 || step > 3) return;
    state = state.copyWith(currentStep: step);
  }

  void nextStep() {
    if (state.currentStep >= 3) return;
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  void previousStep() {
    if (state.currentStep <= 1) return;
    state = state.copyWith(currentStep: state.currentStep - 1);
  }

  void completeStep(int step) {
    if (state.completedSteps.contains(step)) return;
    state = state.copyWith(completedSteps: [...state.completedSteps, step]);
  }

  void markStepIncomplete(int step) {
    if (!state.completedSteps.contains(step)) return;
    state = state.copyWith(
      completedSteps: state.completedSteps.where((s) => s != step).toList(),
    );
  }

  void lockNavigation() =>
      state = state.copyWith(isNavigationLocked: true);

  void unlockNavigation() =>
      state = state.copyWith(isNavigationLocked: false);

  void reset() => state = const WizardController();

  /// Current step — for external reads without accessing protected .state.
  int get currentStep => state.currentStep;
}

/// Convenience derived providers
final wizardCurrentStepProvider = Provider<int>(
  (ref) => ref.watch(wizardControllerProvider).currentStep,
);

final wizardCompletedStepsProvider = Provider<List<int>>(
  (ref) => ref.watch(wizardControllerProvider).completedSteps,
);
