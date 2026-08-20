import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';

/// Hive box for the create-activity form draft.
///
/// Kept (and still opened at startup) even though the multi-step wizard's
/// DraftStorage was removed along with that flow: existing installs have a box
/// under this name on disk, and the single-scroll create screen is the natural
/// place to reintroduce draft-resume. Renaming it now would orphan that data.
const String _draftBoxName = 'wizard_draft';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await Env.load();

  await Hive.initFlutter();
  await Hive.openBox(_draftBoxName);

  runApp(const ProviderScope(child: MatchUpApp()));
}
