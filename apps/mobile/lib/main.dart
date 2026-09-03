import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';

/// Hive box for the create-activity form draft.
const String _draftBoxName = 'wizard_draft';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await Env.load();

  await Hive.initFlutter();
  await Hive.openBox(_draftBoxName);

  runApp(const ProviderScope(child: MatchUpApp()));
}
