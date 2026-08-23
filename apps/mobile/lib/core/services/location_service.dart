import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Thin wrapper around [geolocator] for the chat "share location" attachment
/// (`_InputBar`'s `+` menu in `chat_screen.dart`). Mirrors the degrade-
/// gracefully pattern used by [BiometricService] / [CalendarService]: every
/// failure mode (services disabled, permission denied, permission denied
/// forever) returns `null` instead of throwing, so the call site only needs
/// to branch on "did we get a position".
class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// Requests permission (if needed) and returns the device's current
  /// position, or `null` if location services are disabled or permission
  /// was refused.
  Future<Position?> getCurrentLocation() async {
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

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('LocationService.getCurrentLocation: $e');
      return null;
    }
  }
}
