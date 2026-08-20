/// Route name for the wizard
const String createActivityWizardRouteName = '/create-activity';

/// Route name for wizard steps
String wizardStepRouteName(int step) => '$createActivityWizardRouteName/step-$step';

/// Get wizard step from location
int? getWizardStepFromLocation(String location) {
  final match = RegExp(r'/step-(\d+)').firstMatch(location);
  return match?.group(1) != null ? int.tryParse(match!.group(1)!) : null;
}
