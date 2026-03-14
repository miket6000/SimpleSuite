import 'package:gps_tracker/models/tracker_data.dart';

import '../models/gps_fix.dart';
import '../models/telemetry_model.dart';
import 'geo_tools.dart';

class TelemetryTracker {
  GpsFix? _remoteFix;
  GpsFix? _localFix;
  GpsFix? _lastRemoteFix;
  String? _remoteId;
  int _rssi = 0;
  TelemetryModel? _latest;
  // track whether the most recent remote packet reported a valid fix
  bool _lastPacketHadFix = false;

  // Track consecutive identical remote responses to detect offline state
  String? _lastRemoteResponse;
  int _identicalResponseCount = 0;
  static const int _offlineThreshold =
      3; // Number of identical responses before marking offline
  DateTime? _lastUniqueRemotePacketTime;

  TelemetryModel? get telemetry => _latest;
  GpsFix? get remoteFix => _remoteFix;
  GpsFix? get localFix => _localFix;
  bool get lastPacketHadFix => _lastPacketHadFix;
  DateTime? get lastUniqueRemotePacketTime => _lastUniqueRemotePacketTime;

  /// True if the remote tracker is currently online (receiving new responses)
  /// False if we've seen the same response repeated too many times or haven't received any packets yet
  bool get isRemoteOnline =>
      _lastRemoteResponse != null &&
      _identicalResponseCount < _offlineThreshold;

  void updateRemoteUid(RemoteUIDResponse data) {
    _remoteId = data.remoteId;
    _rssi = data.rssi;
    // No GPS fix in this packet, but rebuild telemetry so RSSI updates in the UI
    if (_remoteFix != null) {
      _updateTelemetry();
    }
  }

  /// Track whether we're getting new remote responses or seeing duplicates
  void _trackRemoteResponse(RemoteResponse data) {
    // Create a hashable string representation of the response data
    final responseHash =
        '${data.remoteId}|${data.fix.latitude}|${data.fix.longitude}|${data.fix.altitude}|${data.fix.timestamp}|${data.rssi}';

    if (_lastRemoteResponse == responseHash) {
      // Same response as last time
      _identicalResponseCount++;
    } else {
      // New response received
      _lastRemoteResponse = responseHash;
      _identicalResponseCount = 0;
      _lastUniqueRemotePacketTime = DateTime.now();
    }
  }

  void updateRemote(RemoteResponse data) {
    // Track response freshness
    _trackRemoteResponse(data);

    // Always update RSSI/ID
    _remoteId = data.remoteId;
    _rssi = data.rssi;

    final hasFix = data.fix.hasFix ?? false;
    _lastPacketHadFix = hasFix;
    if (hasFix) {
      _lastRemoteFix = _remoteFix;
      _remoteFix = data.fix;
    }

    _updateTelemetry();
  }

  void updateLocal(LocalResponse data) {
    _localFix = data.fix;
    _updateTelemetry();
  }

  /// Reset remote tracking state (called on disconnect)
  void resetRemoteTracking() {
    _lastRemoteResponse = null;
    _identicalResponseCount = 0;
    _lastUniqueRemotePacketTime = null;
  }

  void _updateTelemetry() {
    if (_remoteId == null) {
      _latest = null;
      return;
    }

    double? verticalVelocity;
    double? distance;
    double? bearing;
    double? elevation;

    if (_remoteFix != null && _lastRemoteFix != null) {
      final dtMs = _remoteFix!.timestamp
              ?.difference(_lastRemoteFix!.timestamp ?? DateTime(0))
              .inMilliseconds ??
          0;
      final dt = dtMs / 1000.0;
      final dz = (_remoteFix!.altitude ?? 0) - (_lastRemoteFix!.altitude ?? 0);
      verticalVelocity = dt > 0 ? dz / dt : 0;
    }

    if (_localFix != null && _remoteFix != null) {
      distance = distanceBetween(
        _localFix!.latitude,
        _localFix!.longitude,
        _remoteFix!.latitude,
        _remoteFix!.longitude,
      );

      bearing = bearingBetween(
        _localFix!.latitude,
        _localFix!.longitude,
        _remoteFix!.latitude,
        _remoteFix!.longitude,
      );

      elevation = elevationBetween(
        _remoteFix!.altitude,
        _localFix!.altitude,
        distance,
      );
    }

    _latest = TelemetryModel(
      remoteId: _remoteId!,
      remoteFix: _remoteFix,
      localFix: _localFix,
      rssi: _rssi,
      distance: distance,
      bearing: bearing,
      elevation: elevation,
      verticalVelocity: verticalVelocity,
    );
  }
}
