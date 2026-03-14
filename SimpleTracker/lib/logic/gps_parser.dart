import '../models/gps_fix.dart';

class GpsParser {
  static GpsFix? parseGga(String sentence) {
    if (!sentence.startsWith(r'$') || !sentence.contains('*') || !sentence.contains('GGA')) {
      return null;
    }

    final checksumIndex = sentence.indexOf('*');
    final withoutDollar = sentence.substring(1, checksumIndex);
    final checksumStr = sentence.substring(checksumIndex + 1).trim();

    // Compute checksum
    int checksum = 0;
    for (int i = 0; i < withoutDollar.length; i++) {
      checksum ^= withoutDollar.codeUnitAt(i);
    }

    final expected = checksum.toRadixString(16).toUpperCase().padLeft(2, '0');

    if (expected != checksumStr.toUpperCase()) {
      return null; // Checksum failed
    }

    final parts = withoutDollar.split(',');

    if (parts.length < 10) return null;

    final rawTime = parts[1];
    final rawLat = parts[2];
    final latDir = parts[3];
    final rawLon = parts[4];
    final lonDir = parts[5];
    final hasFix = (int.tryParse(parts[6]) ?? 0) > 0;
    final numSatellites = int.tryParse(parts[7]);
    final rawAlt = parts[9];
  

    DateTime? parseTime(String value) {
      try {
        int year = DateTime.now().year;
        int month = DateTime.now().month;
        int day = DateTime.now().day;
        
        int hours = int.parse(rawTime.substring(0, 2));
        int minutes = int.parse(rawTime.substring(2, 4));
        int seconds = int.parse(rawTime.substring(4, 6));

  
        DateTime utcTime = DateTime.utc(year, month, day, hours, minutes, seconds);

        return utcTime.toLocal();
      } catch (e) {
        return null;
      }
    }

    double? parseLat(String value, String dir) {
      try {
        final deg = double.parse(value.substring(0, 2));
        final min = double.parse(value.substring(2));
        final sign = dir == 'S' ? -1 : 1;
        return sign * (deg + min / 60.0);
      } catch (e) {
        return null;
      }
    }

    double? parseLon(String value, String dir) {
      try {
        final deg = double.parse(value.substring(0, 3));
        final min = double.parse(value.substring(3));
        final sign = dir == 'W' ? -1 : 1;
        return sign * (deg + min / 60.0);
      } catch (e) {
        return null;
      }
    }


    final lat = parseLat(rawLat, latDir);
    final lon = parseLon(rawLon, lonDir);
    double? alt;
    try {
      alt = double.parse(rawAlt);
    } catch (_) {}
    final now = parseTime(rawTime);

    return GpsFix(
      hasFix: hasFix,
      timestamp: now,
      latitude: lat,
      longitude: lon,
      altitude: alt,
      numSatellites: numSatellites,
    );

  }
}
