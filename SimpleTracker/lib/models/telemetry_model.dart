import 'gps_fix.dart';

class TelemetryModel {
  final String remoteId;
  final GpsFix? localFix;
  final GpsFix? remoteFix;
  final int rssi;
  final double? verticalVelocity; // m/s
  final double? distance;         // meters
  final double? bearing;          // degrees
  final double? elevation;        // degrees

  TelemetryModel({
    required this.remoteId,
    required this.localFix,
    required this.remoteFix,
    required this.rssi,
    required this.verticalVelocity,
    required this.distance,
    required this.bearing,
    required this.elevation,
  });
}