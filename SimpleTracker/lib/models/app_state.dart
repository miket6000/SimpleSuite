/// Represents the top-level operational state of the application.
///
/// The provider holds exactly one of these values at any time.
/// Each state implies what polling/commands are active and what the UI should show.
enum TrackerState {
  /// No USB connection to the ground station.
  disconnected,

  /// Opening the serial port and querying the ground station UID.
  connecting,

  /// Connected to the ground station, not scanning or paired.
  idle,

  /// SCAN sent, polling D for discovery results.
  scanning,

  /// PAIR command sent, awaiting TACK from the remote tracker.
  pairing,

  /// Paired and receiving tracking data (polling R + L).
  tracking,

  /// Sweeping channels 1-24 listening for active trackers.
  channelScanning,
}
