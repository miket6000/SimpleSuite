/// Immutable LoRa radio configuration used for pairing and channel switching.
class LoraConfig {
  final int frequencyHz;
  final int spreadingFactor;
  final int bandwidth;

  const LoraConfig({
    required this.frequencyHz,
    required this.spreadingFactor,
    required this.bandwidth,
  });

  /// Default discovery channel (all devices boot to this).
  static const discovery = LoraConfig(
    frequencyHz: 434000000,
    spreadingFactor: 9,
    bandwidth: 4,
  );

  /// Format as space-separated parameters for serial commands.
  String toParams() => '$frequencyHz $spreadingFactor $bandwidth';

  @override
  String toString() =>
      'LoraConfig(freq=$frequencyHz, sf=$spreadingFactor, bw=$bandwidth)';
}

/// A remote tracker that has been discovered via SCAN or channel scan.
///
/// Each device is assigned a dedicated [LoraConfig] tracking channel when
/// first seen. [isPaired] tracks whether both sides already know the
/// tracking channel:
///   - `false` — found via discovery scan, needs PAIR to negotiate.
///   - `true`  — found on a channel scan or PAIR completed, just use C.
class DiscoveredDevice {
  final String uid;
  int rssi;
  final LoraConfig trackingConfig;
  final String channelName;
  bool isPaired;

  DiscoveredDevice({
    required this.uid,
    required this.rssi,
    required this.trackingConfig,
    required this.channelName,
    this.isPaired = false,
  });

  @override
  String toString() => 'DiscoveredDevice($uid, rssi=$rssi, '
      'paired=$isPaired, ch=$trackingConfig)';
}

/// A tracker found during a channel-scan sweep.
class ChannelScanHit {
  final String uid;
  final int rssi;
  final int channelIndex;
  final String channelName;
  final LoraConfig config;

  ChannelScanHit({
    required this.uid,
    required this.rssi,
    required this.channelIndex,
    required this.channelName,
    required this.config,
  });
}
