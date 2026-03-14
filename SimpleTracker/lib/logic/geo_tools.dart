import 'dart:math';

double? distanceBetween(double? lat1, double? lon1, double? lat2, double? lon2) {
  if (lat1 == null || lat2 == null || lon1 == null || lon2 == null) {
    return null;
  }
  
  const earthRadius = 6371000; // in meters (assume a sphere, probably close enough...)

  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degreesToRadians(double degrees) {
  return degrees * pi / 180;
}

double? bearingBetween(double? lat1, double? lon1, double? lat2, double? lon2) {
  if (lat1 == null || lat2 == null || lon1 == null || lon2 == null) {
    return null;
  }

  final lat1Rad = _degreesToRadians(lat1);
  final lat2Rad = _degreesToRadians(lat2);
  final dLon = _degreesToRadians(lon2 - lon1);

  final y = sin(dLon) * cos(lat2Rad);
  final x = cos(lat1Rad) * sin(lat2Rad) -
      sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

  double bearing = atan2(y, x);
  bearing = _radiansToDegrees(bearing);
  return (bearing + 360) % 360; // Normalize to 0-360
}

double _radiansToDegrees(double radians) {
  return radians * 180 / pi;
}

double? elevationBetween(double? alt1, double? alt2, double? distance) {
  if (alt1 == null || alt2 == null || distance == null) {
    return null;
  }

  double elevation = atan2(alt2 - alt1, distance);
  elevation = _radiansToDegrees(elevation);
  return elevation;
}

String? bearingToCompass(double? bearing) {
  if (bearing == null) {
    return null;
  }
  
  // Normalize the bearing to 0–360°
  final normalized = (bearing % 360 + 360) % 360;

  const directions = [
    "N", "NNE", "NE", "ENE",
    "E", "ESE", "SE", "SSE",
    "S", "SSW", "SW", "WSW",
    "W", "WNW", "NW", "NNW"
  ];

  final index = ((normalized / 22.5) + 0.5).floor() % 16;
  return directions[index];
}  