import 'package:gps_tracker/models/gps_fix.dart';

class LocalResponse {
  final GpsFix fix;
  LocalResponse({required this.fix});
}

class RemoteResponse {
  final String remoteId;
  final GpsFix fix;
  final int rssi;
  RemoteResponse(
      {required this.remoteId, required this.fix, required this.rssi});
}

class RemoteUIDResponse {
  final String remoteId;
  final int rssi;
  RemoteUIDResponse({required this.remoteId, required this.rssi});
}

/// A single entry from a SCAN/D discovery cycle (raw parse result).
class ScanResult {
  final String uid;
  final int rssi;
  ScanResult({required this.uid, required this.rssi});
}

/// Discovery not started (D returns NONE)
class DiscoveryNoneResponse {}

/// Discovery in progress (D returns WAIT <count>)
class DiscoveryWaitResponse {
  final int count;
  DiscoveryWaitResponse({required this.count});
}

/// Discovery complete (D returns <count> <uid1>,<rssi1> ...)
class DiscoveryCompleteResponse {
  final int count;
  final List<ScanResult> devices;
  DiscoveryCompleteResponse({required this.count, required this.devices});
}

/// PAIR ACK received via R command
class PairAckResponse {
  final String remoteId;
  PairAckResponse({required this.remoteId});
}

/// Voltage response received via R command
class VoltageResponse {
  final String remoteId;
  final int millivolts;
  VoltageResponse({required this.remoteId, required this.millivolts});
}

/// UID response from the UID command
class UidResponse {
  final String uid;
  UidResponse({required this.uid});
}

class SettingResponse {
  final String key;
  final int value;
  SettingResponse({required this.key, required this.value});
}

class CommandStatus {
  final String response;
  CommandStatus({required this.response});
}

class UnknownResponse {
  final String raw;
  UnknownResponse({required this.raw});
}
