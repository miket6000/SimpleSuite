import '../models/lora_config.dart';
import 'ground_station_service.dart';
import 'logging_service.dart';

// ============================
// Setting Model
// ============================

/// A single device setting that can be read/written over serial.
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

  @override
  String toString() => '$title ($commandChar): $value';
}

// ============================
// Option Maps (constants from COMMUNICATION_SPEC.md §4)
// ============================

const Map<String, int> spreadingFactorOptions = {
  '5': 5, '6': 6, '7': 7, '8': 8,
  '9': 9, '10': 10, '11': 11, '12': 12,
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
  '4/5': 1, '4/6': 2, '4/7': 3, '4/8': 4,
};

const Map<String, int> powerOptions = {
  '-9 dBm': -9, '-8 dBm': -8, '-7 dBm': -7, '-6 dBm': -6,
  '-5 dBm': -5, '-4 dBm': -4, '-3 dBm': -3, '-2 dBm': -2,
  '-1 dBm': -1, ' 0 dBm': 0, ' 1 dBm': 1, ' 2 dBm': 2,
  ' 3 dBm': 3, ' 4 dBm': 4, ' 5 dBm': 5, ' 6 dBm': 6,
  ' 7 dBm': 7, ' 8 dBm': 8, ' 9 dBm': 9, ' 10 dBm': 10,
  ' 11 dBm': 11, ' 12 dBm': 12, ' 13 dBm': 13, ' 14 dBm': 14,
  ' 15 dBm': 15, ' 16 dBm': 16, ' 17 dBm': 17, ' 18 dBm': 18,
  ' 19 dBm': 19, ' 20 dBm': 20, ' 21 dBm': 21, ' 22 dBm': 22,
};

const Map<String, int> modeOptions = {
  'Tracker': 1,
  'Ground Station': 2,
};

// ============================
// Channel Presets
// ============================

class ChannelPreset {
  final int number;
  final String name;
  final LoraConfig config;
  final int codingRate;

  const ChannelPreset({
    required this.number,
    required this.name,
    required this.config,
    this.codingRate = 1,
  });
}

const int _baseFrequencyHz = 434000000;
const int _channelSpacingHz = 200000;

final List<ChannelPreset> channelPresets = List.generate(25, (i) {
  final freq = _baseFrequencyHz + _channelSpacingHz * i;
  return ChannelPreset(
    number: i,
    name: 'CH$i (${(freq / 1000000).toStringAsFixed(3)} MHz)',
    config: LoraConfig(frequencyHz: freq, spreadingFactor: 9, bandwidth: 4),
  );
});

// ============================
// Settings Service
// ============================

/// Manages device settings: creates fresh instances, loads from device,
/// and uploads changed values.
class SettingsService {
  final GroundStationService _gs;
  final LoggingService _log;
  late final Map<String, Setting> settings;

  SettingsService({
    required GroundStationService gs,
    required LoggingService log,
  })  : _gs = gs,
        _log = log {
    settings = _createDefaults();
  }

  /// Create a fresh set of default settings (no mutable global).
  static Map<String, Setting> _createDefaults() => {
        'f': Setting(
          commandChar: 'f', title: 'Frequency', value: 434000000,
          hint: 'The center frequency in Hz.',
        ),
        's': Setting(
          commandChar: 's', title: 'Spread Factor', value: 9,
          options: spreadingFactorOptions,
          hint: 'Length of chirp. Affects range and transmission time.',
        ),
        'b': Setting(
          commandChar: 'b', title: 'Bandwidth', value: 4,
          options: bandwidthOptions,
          hint: 'Lower bandwidth increases range but reduces speed.',
        ),
        'c': Setting(
          commandChar: 'c', title: 'Coding Rate', value: 1,
          options: codingRateOptions,
          hint: 'Ratio of data bits to transmitted bits.',
        ),
        'd': Setting(
          commandChar: 'd', title: 'Transmit Power', value: 22,
          options: powerOptions,
          hint: 'Transmit power in dBm.',
        ),
        'o': Setting(
          commandChar: 'o', title: 'Over-current', value: 150,
          hint: 'Over-current protection limit in mA.',
        ),
        'p': Setting(
          commandChar: 'p', title: 'Preamble Length', value: 8,
          hint: 'Symbols used for synchronization.',
        ),
        'm': Setting(
          commandChar: 'm', title: 'Mode', value: 2,
          options: modeOptions,
          hint: '1 = Tracker, 2 = Ground Station.',
        ),
      };

  /// Load all settings from the connected device.
  Future<void> loadFromDevice() async {
    for (final entry in settings.entries) {
      try {
        final value = await _gs.getSetting(entry.key);
        if (value != null) {
          entry.value.value = value;
          entry.value.initialValue = value;
        }
      } catch (e) {
        await _log.error('Failed to load setting ${entry.key}: $e');
      }
    }
  }

  /// Upload all modified settings to the device.
  /// Returns true if all succeeded, false if any failed.
  Future<bool> uploadToDevice() async {
    bool allOk = true;
    for (final entry in settings.entries) {
      if (entry.value.modified) {
        final ok = await _gs.setSetting(entry.key, entry.value.value);
        if (ok) {
          entry.value.initialValue = entry.value.value;
          await _log.info('Setting ${entry.key} updated to ${entry.value.value}');
        } else {
          await _log.error('Device rejected setting ${entry.key}');
          allOk = false;
        }
      }
    }
    return allOk;
  }

  /// Apply a channel preset to the local settings model.
  void applyChannelPreset(ChannelPreset preset) {
    settings['f']?.value = preset.config.frequencyHz;
    settings['s']?.value = preset.config.spreadingFactor;
    settings['b']?.value = preset.config.bandwidth;
    settings['c']?.value = preset.codingRate;
  }
}
