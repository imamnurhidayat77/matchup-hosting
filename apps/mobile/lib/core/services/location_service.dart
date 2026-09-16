import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thrown by [LocationService.getCurrentLocation] when the GPS fix
/// itself times out (as opposed to a permission denial, which still
/// returns `null`). Lets callers distinguish "no fix yet — retry" from
/// "no permission — explain / open settings".
class LocationTimeoutException implements Exception {
  const LocationTimeoutException([this.message = 'location fix timed out']);
  final String message;
  @override
  String toString() => 'LocationTimeoutException($message)';
}

/// Thin wrapper around [geolocator] for the chat "share location" attachment
/// (`_InputBar`'s `+` menu in `chat_screen.dart`). Mirrors the degrade-
/// gracefully pattern used by [BiometricService] / [CalendarService]: every
/// failure mode (services disabled, permission denied, permission denied
/// forever) returns `null` instead of throwing, so the call site only needs
/// to branch on "did we get a position". The one exception is a GPS
/// [LocationTimeoutException]: a fix that never arrives is transient and
/// worth an explicit retry message rather than a permissions lecture.
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// Test-only override. When set, [getCurrentLocation] invokes this
  /// instead of touching the Geolocator platform channels (which hang
  /// under `flutter_test` without a mocked method channel and would
  /// stall `pumpAndSettle`). Reset to `null` in tearDown.
  @visibleForTesting
  static Future<Position?> Function()? debugGetCurrentLocation;

  /// Requests permission (if needed) and returns the device's current
  /// position, or `null` if location services are disabled or permission
  /// was refused. Throws [LocationTimeoutException] when the GPS fix
  /// itself times out — callers must catch it separately from the
  /// `null` (denial) path.
  Future<Position?> getCurrentLocation() async {
    final debugOverride = debugGetCurrentLocation;
    if (debugOverride != null) return debugOverride();
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Bound the GPS wait: on an emulator without a mock location
      // (or indoors with no fix) `getCurrentPosition` can hang for
      // tens of seconds, which stalls every feed that awaits it
      // (Discover skulls, venue ranking). 4s then degrade to null.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('LocationService.getCurrentLocation: timed out');
          }
          throw const LocationTimeoutException();
        },
      );
    } on LocationTimeoutException {
      // A slow fix is transient, not a denial — propagate so the caller
      // can offer a retry instead of a permissions lecture.
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('LocationService.getCurrentLocation: $e');
      return null;
    }
  }

  /// True when the user permanently denied location permission
  /// ("don't ask again"). Callers use this after a `null` fix to decide
  /// between a plain permissions hint and a snackbar with an
  /// "Open Settings" action (the only recovery path — the OS will no
  /// longer show the permission prompt).
  Future<bool> isPermissionPermanentlyDenied() async {
    if (debugGetCurrentLocation != null) return false;
    try {
      return await Geolocator.checkPermission() ==
          LocationPermission.deniedForever;
    } catch (_) {
      return false;
    }
  }
}
