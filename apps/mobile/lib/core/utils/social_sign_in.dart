import 'package:flutter/material.dart';

import '../widgets/app_snackbar.dart';

/// Honest state for Apple/Google sign-in: there is no OAuth client behind
/// those buttons yet, so tapping one explains that instead of looking
/// tappable and going nowhere (or pretending to start an OAuth flow).
/// All three auth screens (welcome / login / register) share this copy.
const String socialSignInUnavailableMessage =
    'Social sign-in belum tersedia — gunakan email';

/// Shows the "social sign-in unavailable" notice. Uses the app-wide
/// [AppSnackbar] (a floating SnackBar) so the pattern matches every
/// other transient notice in the app.
void showSocialSignInUnavailable(BuildContext context) {
  AppSnackbar.show(
    context,
    message: socialSignInUnavailableMessage,
    variant: AppSnackbarVariant.info,
  );
}
