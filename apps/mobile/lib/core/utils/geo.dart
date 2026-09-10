import 'dart:math' as math;

/// Great-circle distance between two WGS-84 points, in kilometres.
/// Used to turn the backend's raw `latitude`/`longitude` into the
/// `distanceKm` shown on discovery cards (the API has no geo queries,
/// so the phone does the math).
double haversineKm(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusKm = 6371.0;
  final dLat = _radians(lat2 - lat1);
  final dLon = _radians(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _radians(double degrees) => degrees * math.pi / 180.0;
