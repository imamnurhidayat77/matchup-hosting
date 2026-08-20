import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchup_mobile/features/activities/presentation/wizard/providers/wizard_controller_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  WizardController state() => container.read(wizardControllerProvider);
  WizardControllerNotifier notifier() =>
      container.read(wizardControllerProvider.notifier);

  group('WizardControllerNotifier', () {
    test('should initialise at step 1', () {
      expect(state().currentStep, 1);
      expect(state().isFirstStep, isTrue);
      expect(state().isLastStep, isFalse);
    });

    test('should advance to next step via nextStep', () {
      notifier().nextStep();
      expect(state().currentStep, 2);
    });

    test('should go back to previous step via previousStep', () {
      notifier().nextStep(); // step 2
      notifier().previousStep();
      expect(state().currentStep, 1);
    });

    test('should not go below step 1', () {
      notifier().previousStep();
      expect(state().currentStep, 1);
    });

    test('should not go above step 3', () {
      notifier().nextStep();
      notifier().nextStep();
      notifier().nextStep(); // attempt step 4 — capped at 3
      expect(state().currentStep, 3);
    });

    test('should report isLastStep at step 3', () {
      notifier().setStep(3);
      expect(state().isLastStep, isTrue);
    });

    test('should jump directly to a specific step via setStep', () {
      notifier().setStep(3);
      expect(state().currentStep, 3);
    });

    test('should ignore invalid step values in setStep', () {
      notifier().setStep(0);
      expect(state().currentStep, 1); // unchanged

      notifier().setStep(5);
      expect(state().currentStep, 1); // unchanged
    });

    test('should track completed steps via completeStep', () {
      notifier().completeStep(1);
      expect(state().completedSteps, contains(1));
    });

    test('should not duplicate steps in completedSteps', () {
      notifier().completeStep(1);
      notifier().completeStep(1);
      expect(state().completedSteps.where((s) => s == 1).length, 1);
    });

    test('should remove step via markStepIncomplete', () {
      notifier().completeStep(1);
      notifier().markStepIncomplete(1);
      expect(state().completedSteps, isNot(contains(1)));
    });

    test('should toggle navigation lock', () {
      expect(state().isNavigationLocked, isFalse);
      notifier().lockNavigation();
      expect(state().isNavigationLocked, isTrue);
      notifier().unlockNavigation();
      expect(state().isNavigationLocked, isFalse);
    });

    test('should reset to defaults via reset', () {
      notifier().setStep(3);
      notifier().completeStep(1);
      notifier().completeStep(2);
      notifier().reset();
      expect(state().currentStep, 1);
      expect(state().completedSteps, isEmpty);
    });

    test('should expose currentStep without accessing protected .state', () {
      notifier().setStep(2);
      expect(notifier().currentStep, 2);
    });

    test('isStepCompleted should return true for a completed step', () {
      notifier().completeStep(2);
      expect(state().isStepCompleted(2), isTrue);
      expect(state().isStepCompleted(3), isFalse);
    });
  });

  group('derived providers', () {
    test('wizardCurrentStepProvider reflects current step', () {
      notifier().setStep(3);
      expect(container.read(wizardCurrentStepProvider), 3);
    });

    test('wizardCompletedStepsProvider reflects completed steps', () {
      notifier().completeStep(1);
      notifier().completeStep(2);
      final completed = container.read(wizardCompletedStepsProvider);
      expect(completed, containsAll([1, 2]));
    });
  });
}
