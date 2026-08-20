// Root test entry-point — re-exports all test suites so `flutter test` picks
// them up with a single pass. Individual test files live in subdirectories.
//
// Run:  flutter test --no-pub
// Coverage: flutter test --no-pub --coverage

import 'unit/domain/activity_model_test.dart' as activity_model;
import 'unit/services/form_validator_test.dart' as form_validator;
import 'unit/services/image_processor_test.dart' as image_processor;
import 'unit/services/auth_recovery_test.dart' as auth_recovery;
import 'unit/network/api_exception_test.dart' as api_exception;
import 'providers/form_data_notifier_test.dart' as form_data_notifier;
import 'providers/wizard_controller_test.dart' as wizard_controller;
import 'providers/auth_state_test.dart' as auth_state;
import 'providers/repository_toggle_test.dart' as repository_toggle;
import 'widget/app_card_test.dart' as app_card;
import 'widget/app_button_test.dart' as app_button;
import 'widget/empty_state_test.dart' as empty_state;
import 'integration/discovery_feed_test.dart' as discovery_feed;

void main() {
  activity_model.main();
  form_validator.main();
  image_processor.main();
  auth_recovery.main();
  api_exception.main();
  form_data_notifier.main();
  wizard_controller.main();
  auth_state.main();
  repository_toggle.main();
  app_card.main();
  app_button.main();
  empty_state.main();
  discovery_feed.main();
}
