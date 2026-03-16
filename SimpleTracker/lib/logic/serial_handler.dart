import '../models/tracker_data.dart';
import 'gps_parser.dart';

class SerialHandler {
  static final _uidPattern = RegExp(r'^[0-9a-fA-F]{8}$');

  /// Validate that a string is a valid 32-bit hex UID (8 hex chars).
  static bool _isValidUid(String s) => _uidPattern.hasMatch(s);

  dynamic parse(String command, String response) {
    // --- UID command: returns 8-char hex UID ---
    if (command == 'UID') {
      final trimmed = response.trim();
      if (_isValidUid(trimmed)) {
        return UidResponse(uid: trimmed);
      }
      return UnknownResponse(raw: response);
    }

    // --- L command: local GPS NMEA sentence ---
    if (command == 'L') {
      final fix = GpsParser.parseGga(response);
      if (fix != null) {
        return LocalResponse(fix: fix);
      } else {
        return UnknownResponse(raw: response);
      }
    }

    // --- D command: discovery poll results ---
    if (command == 'D') {
      final trimmed = response.trim();

      // No scan initiated
      if (trimmed == 'NONE') {
        return DiscoveryNoneResponse();
      }

      // Scan in progress: "WAIT <count>"
      if (trimmed.startsWith('WAIT')) {
        final parts = trimmed.split(' ');
        final count = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        return DiscoveryWaitResponse(count: count);
      }

      // Scan complete: "<count> <uid1>,<rssi1> <uid2>,<rssi2> ..."
      final parts = trimmed.split(' ');
      final count = int.tryParse(parts[0]);
      if (count != null && count >= 0) {
        final devices = <ScanResult>[];
        for (int i = 1; i < parts.length; i++) {
          final pair = parts[i].split(',');
          if (pair.length == 2) {
            final uid = pair[0];
            final rssi = int.tryParse(pair[1]);
            if (rssi != null && _isValidUid(uid)) {
              devices.add(ScanResult(uid: uid, rssi: rssi));
            }
          }
        }
        return DiscoveryCompleteResponse(count: count, devices: devices);
      }

      return UnknownResponse(raw: response);
    }

    // --- R command: read last received LoRa message ---
    if (command == 'R') {
      final trimmed = response.trim();
      if (trimmed.isEmpty) {
        return UnknownResponse(raw: response);
      }

      // Check for PAIR ACK: "<tracker_uid> &<gs_uid>TACK"
      if (trimmed.contains('TACK')) {
        final parts = trimmed.split(' ');
        if (parts.isNotEmpty && _isValidUid(parts[0])) {
          return PairAckResponse(remoteId: parts[0]);
        }
      }

      // Check for voltage response: "<tracker_uid> &<gs_uid>V<millivolts>"
      final voltageMatch = RegExp(r'^([0-9a-fA-F]{8})\s+&[0-9a-fA-F]{8}V(\d+)$')
          .firstMatch(trimmed);
      if (voltageMatch != null) {
        return VoltageResponse(
          remoteId: voltageMatch.group(1)!,
          millivolts: int.parse(voltageMatch.group(2)!),
        );
      }

      // GPS tracking data: "<tracker_uid> <NMEA_sentence> <rssi>"
      // The UID is 8 hex chars, then a space, then NMEA starting with $, then RSSI at end
      final parts = trimmed.split(' ');
      if (parts.length >= 3 && _isValidUid(parts[0])) {
        final id = parts[0];
        // RSSI is the last element
        final rssi = int.tryParse(parts.last);
        if (rssi != null) {
          // NMEA sentence is everything between UID and RSSI
          final nmeaStr = parts.sublist(1, parts.length - 1).join(' ');
          final fix = GpsParser.parseGga(nmeaStr);
          if (fix != null) {
            return RemoteResponse(remoteId: id, fix: fix, rssi: rssi);
          }
          // NMEA parse failed (checksum error, non-GGA, etc.)
          // Still return the UID and RSSI so the UI stays updated
          return RemoteUIDResponse(remoteId: id, rssi: rssi);
        }
      }

      // Also handle 2-part responses: "<uid> <rssi>" (no NMEA)
      if (parts.length == 2 && _isValidUid(parts[0])) {
        final rssi = int.tryParse(parts[1]);
        if (rssi != null) {
          return RemoteUIDResponse(remoteId: parts[0], rssi: rssi);
        }
      }

      return UnknownResponse(raw: response);
    }

    // --- SCAN command: returns OK ---
    if (command == 'SCAN') {
      return CommandStatus(response: response.trim());
    }

    // --- PAIR command: returns OK or ERR ---
    if (command.startsWith('PAIR')) {
      return CommandStatus(response: response.trim());
    }

    // --- T command (raw transmit): returns OK or ERR ---
    if (command.startsWith('T ')) {
      return CommandStatus(response: response.trim());
    }

    // --- C command (channel switch): returns OK or ERR ---
    if (command.startsWith('C ')) {
      return CommandStatus(response: response.trim());
    }

    // --- GET command ---
    if (command.startsWith("GET ")) {
      final key = command.split(" ").last;
      final value = int.tryParse(response.trim());
      if (value != null) {
        return SettingResponse(key: key, value: value);
      }
      return UnknownResponse(raw: response);
    }

    // --- SET command ---
    if (command.startsWith("SET ")) {
      return CommandStatus(response: response.trim());
    }

    // --- REBOOT ---
    if (command == 'REBOOT') {
      return CommandStatus(response: response.trim());
    }

    // --- FACTORY ---
    if (command == 'FACTORY') {
      return CommandStatus(response: response.trim());
    }

    return UnknownResponse(raw: response);
  }
}
