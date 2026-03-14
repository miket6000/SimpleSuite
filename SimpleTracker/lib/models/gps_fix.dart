class GpsFix {
  final bool? hasFix;
  final DateTime? timestamp;
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final num? numSatellites;

  GpsFix({
    required this.hasFix,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.numSatellites,
  });
}