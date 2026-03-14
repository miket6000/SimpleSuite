import 'dart:typed_data';
import 'channels.dart';

// ============================
// Generic Setting Class
// ============================
class Setting {
  final String commandChar;
  final String title;
  final String hint;
  final bool configurable;
  final Map<String, int>? options;
  int value;
  int? initialValue;

  Setting({
    required this.commandChar,
    required this.title,
    required this.value,
    this.initialValue,
    this.options,
    this.configurable = true,
    this.hint = '',
  });

  bool get modified => (initialValue != null) && (value != initialValue);

  String serialize() => 'SET $commandChar ${_serializeValue()}\n';

  void deserialize(String input) {
    value = int.parse(input);
  }

  String _serializeValue() => value.toString();

  @override
  String toString() => '$title ($commandChar): $value';
}

// ============================
// Unit Class
// ============================
class Unit {
  final String title;
  final double slope;
  final double offset;
  const Unit({required this.title, required this.slope, required this.offset});
}

// ============================
// Settings Definitions
// ============================
final Map<String, Setting> defaultSettings = {
  'f': Setting(
    commandChar: 'f',
    title: 'Frequency',
    value: 434000000,
    hint: 'The center frequency in Hz.',
  ),
  's': Setting(
    commandChar: 's',
    title: 'Spread Factor',
    value: 9,
    options: spreadingFactorOptions,
    hint: 'Length of chirp. Affects range and transmission time.',
  ),
  'b': Setting(
    commandChar: 'b',
    title: 'Bandwidth',
    value: 4,
    options: bandwidthOptions,
    hint: 'Lower bandwidth increases range but reduces speed.',
  ),
  'c': Setting(
    commandChar: 'c',
    title: 'Coding Rate',
    value: 1,
    options: codingRateOptions,
    hint:
        'Ratio of data bits to transmitted bits. Higher improves error correction but increases airtime.',
  ),
  'd': Setting(
    commandChar: 'd',
    title: 'Transmit Power',
    value: 22,
    options: powerOptions,
    hint: 'Transmit power in dBm. Higher uses more power.',
  ),
  'o': Setting(
    commandChar: 'o',
    title: 'Over-current',
    value: 150,
    hint: 'Over-current protection limit in mA.',
  ),
  'p': Setting(
    commandChar: 'p',
    title: 'Preamble Length',
    value: 8,
    hint:
        'Bits used for synchronization. Longer preamble can improve reception but increases airtime.',
  ),
  'm': Setting(
    commandChar: 'm',
    title: 'Mode',
    value: 2,
    options: modeOptions,
    hint: '1 = Tracker, 2 = Ground Station.',
  ),
};

// ============================
// Option Maps
// ============================
const Map<String, int> spreadingFactorOptions = {
  '5': 5,
  '6': 6,
  '7': 7,
  '8': 8,
  '9': 9,
  '10': 10,
  '11': 11,
  '12': 12,
};

const Map<String, int> bandwidthOptions = {
  '7.8 kHz': 0x00,
  '10.4 kHz': 0x08,
  '15.6 kHz': 0x01,
  '20.8 kHz': 0x09,
  '31.25 kHz': 0x02,
  '41.7 kHz': 0x0a,
  '62.5 kHz': 0x03,
  '125 kHz': 0x04,
  '250 kHz': 0x05,
  '500 kHz': 0x06,
};

const Map<String, int> codingRateOptions = {
  '4/5': 1,
  '4/6': 2,
  '4/7': 3,
  '4/8': 4,
};

const Map<String, int> powerOptions = {
  '-9 dBm': -9,
  '-8 dBm': -8,
  '-7 dBm': -7,
  '-6 dBm': -6,
  '-5 dBm': -5,
  '-4 dBm': -4,
  '-3 dBm': -3,
  '-2 dBm': -2,
  '-1 dBm': -1,
  ' 0 dBm': 0,
  ' 1 dBm': 1,
  ' 2 dBm': 2,
  ' 3 dBm': 3,
  ' 4 dBm': 4,
  ' 5 dBm': 5,
  ' 6 dBm': 6,
  ' 7 dBm': 7,
  ' 8 dBm': 8,
  ' 9 dBm': 9,
  ' 10 dBm': 10,
  ' 11 dBm': 11,
  ' 12 dBm': 12,
  ' 13 dBm': 13,
  ' 14 dBm': 14,
  ' 15 dBm': 15,
  ' 16 dBm': 16,
  ' 17 dBm': 17,
  ' 18 dBm': 18,
  ' 19 dBm': 19,
  ' 20 dBm': 20,
  ' 21 dBm': 21,
  ' 22 dBm': 22,
};

const Map<String, int> modeOptions = {
  'Tracker': 1,
  'Ground Station': 2,
};

// ============================
// Units Definitions
// ============================
const Map<String, Unit> units = {
  'Hz': Unit(title: 'Frequency', slope: 0.000001, offset: 0),
  'kHz': Unit(title: 'Frequency', slope: 0.001, offset: 0),
  'MHz': Unit(title: 'Frequency', slope: 1, offset: 0),
  'SF': Unit(title: 'Spreading Factor', slope: 1, offset: 0),
  'dBm': Unit(title: 'Power', slope: 1, offset: 0),
  'mA': Unit(title: 'Current', slope: 1, offset: 0),
  'A': Unit(title: 'Current', slope: 0.001, offset: 0),
  '': Unit(title: 'Count', slope: 1, offset: 0),
  'V': Unit(title: 'Voltage', slope: 1000, offset: 0),
  'm': Unit(title: 'Altitude', slope: 100, offset: 0),
  'ft': Unit(title: 'Altitude', slope: 30.48, offset: 0),
  'hPa': Unit(title: 'Pressure', slope: 100, offset: 0),
  'psi': Unit(title: 'Pressure', slope: 6894.75729, offset: 0),
  '°C': Unit(title: 'Temperature', slope: 100, offset: 0),
  '°F': Unit(title: 'Temperature', slope: 180, offset: 32),
  '-': Unit(title: 'Status', slope: 1, offset: 0),
};

void applyChannelPreset(Channel channel) {
  for (final entry in channel.presetValues.entries) {
    final setting = defaultSettings[entry.key];
    if (setting != null) {
      setting.value = entry.value;
    }
  }
}

// ============================
// Byte Swapping Utility
// ============================
int swapBytes(Uint8List bytes) {
  if (bytes.length == 1) return bytes[0].toInt();
  if (bytes.length == 2) {
    return (bytes[1].toInt() << 8) + bytes[0].toInt();
  }
  if (bytes.length == 4) {
    return (bytes[3].toInt() << 24) +
        (bytes[2].toInt() << 16) +
        (bytes[1].toInt() << 8) +
        bytes[0].toInt();
  }
  throw ArgumentError('Invalid number of bytes');
}
