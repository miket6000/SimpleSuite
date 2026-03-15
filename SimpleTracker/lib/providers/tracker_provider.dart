import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_state.dart';
import '../models/lora_config.dart';
import '../models/telemetry_model.dart';
import '../models/tracker_data.dart';
import '../logic/telemetry_tracker.dart';
import '../services/ground_station_service.dart';
import '../services/logging_service.dart';
import '../services/settings_service.dart';

/// Central application provider — owns the state machine, delegates
/// all serial work to [GroundStationService], and exposes telemetry
/// for the UI layer.
class TrackerProvider extends ChangeNotifier {
  // Services
  final LoggingService _log = LoggingService();
  late final GroundStationService _gs;
  late final SettingsService _settings;
  final TelemetryTracker _tracker = TelemetryTracker();

  // State
  TrackerState _state = TrackerState.disconnected;
  String? _selectedPort;
  final Map<String, DiscoveredDevice> _discoveredDevices = {};
  String? _selectedRemoteUID;
  Timer? _portScanTimer;
  Timer? _pollTimer;
  Timer? _uiRefreshTimer;
  List<String> _availablePorts = [];
  bool _connectInProgress = false; // guard against overlapping connect attempts

  /// Next channel index to assign (channels 1-24; 0 is discovery).
  int _nextChannelIndex = 1;

  // Stale-detection baseline for pairing — the raw R response captured
  // just before polling begins so we can distinguish fresh packets.
  String? _pairingBaseline;

  // Channel scan state
  int _channelScanCurrent = 0;        // channel index currently being scanned
  int _channelScanTotal = 0;          // total channels to scan
  final Map<String, ChannelScanHit> _channelScanResults = {};

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  TrackerState get state => _state;
  bool get isConnected => _state != TrackerState.disconnected && _state != TrackerState.connecting;
  bool get isScanning => _state == TrackerState.scanning;
  bool get isPaired => _state == TrackerState.tracking;

  String? get groundStationUid => _gs.groundStationUid;
  String? get selectedPort => _selectedPort;
  List<String> get availablePorts => _availablePorts;

  Map<String, DiscoveredDevice> get discoveredDevices =>
      Map.unmodifiable(_discoveredDevices);
  String? get selectedRemoteUID => _selectedRemoteUID;

  TelemetryModel? get telemetry => _tracker.telemetry;
  bool get remotePacketHasFix => _tracker.lastPacketHadFix;
  bool get isRemoteOnline => _tracker.isRemoteOnline && isConnected;
  DateTime? get lastUniqueRemotePacketTime => _tracker.lastUniqueRemotePacketTime;

  List<String> get logs => _log.log;
  String? get logFilePath => _log.currentLogPath;

  Map<String, Setting> get settings => _settings.settings;

  // Channel scan getters
  bool get isChannelScanRunning => _state == TrackerState.channelScanning;
  int get channelScanCurrent => _channelScanCurrent;
  int get channelScanTotal => _channelScanTotal;
  Map<String, ChannelScanHit> get channelScanResults =>
      Map.unmodifiable(_channelScanResults);

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  TrackerProvider() {
    _gs = GroundStationService(log: _log);
    _settings = SettingsService(gs: _gs, log: _log);

    _gs.onDisconnected = _handleDisconnection;

    _log.onNewEntry = () => notifyListeners();
    _log.init().then((_) => notifyListeners());

    _startPortScanner();
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  void selectPort(String? port) {
    _selectedPort = port;
    notifyListeners();
  }

  Future<void> connect() async {
    if (_selectedPort == null) return;
    if (_connectInProgress) return;
    _connectInProgress = true;

    try {
      _transition(TrackerState.connecting);

      final uid = await _gs.connect(_selectedPort!);
      if (uid == null) {
        _transition(TrackerState.disconnected);
        return;
      }

      // Load device settings
      await _settings.loadFromDevice();

      // If we were previously tracking a device, attempt to re-pair.
      // This handles both cases: tracker still on tracking channel (PAIR
      // will fail, fallback to C) or tracker was power-cycled (PAIR works).
      final previousUID = _selectedRemoteUID;
      final previousDevice = previousUID != null
          ? _discoveredDevices[previousUID]
          : null;

      if (previousDevice != null && previousDevice.isPaired) {
        // Previously tracked via channel scan — just switch directly
        await _log.info(
            'Reconnecting to $previousUID on ${previousDevice.channelName}');
        final ok = await _gs.switchChannel(previousDevice.trackingConfig);
        if (ok) {
          _transition(TrackerState.tracking);
          _startPolling(
            interval: const Duration(seconds: 1),
            action: _pollForTrackingData,
          );
          return;
        }
        await _log.warning('Channel switch failed, falling back to idle');
      } else if (previousDevice != null) {
        // Previously tracked via discovery — try PAIR again
        await _log.info('Re-pairing with previously tracked $previousUID');
        await _gs.switchChannel(LoraConfig.discovery);
        _transition(TrackerState.pairing);

        final ok = await _gs.pair(previousUID!, previousDevice.trackingConfig);
        if (ok) {
          _pairingBaseline = await _gs.readRemoteRaw();
          _startPolling(
            interval: const Duration(seconds: 1),
            action: _pollForTrackingData,
          );
          return;
        }
        await _log.warning('PAIR failed, falling back to idle');
      }

      // No previous pairing — start fresh on discovery channel
      await _gs.switchChannel(LoraConfig.discovery);
      _transition(TrackerState.idle);
    } catch (e) {
      await _log.error('Connect error: $e');
      _transition(TrackerState.disconnected);
    } finally {
      _connectInProgress = false;
    }
  }

  void disconnect() {
    _connectInProgress = false;
    _stopPolling();
    _tracker.resetRemoteTracking();
    _gs.disconnect();
    _transition(TrackerState.disconnected);
  }

  /// Auto-detect and connect to a SimpleTracker ground station.
  Future<bool> autoDetectAndConnect() async {
    try {
      final devices = await _gs.getSimpleTrackerDevices();
      if (devices.length == 1) {
        selectPort(devices.first.portName);
        await connect();
        return true;
      }
    } catch (e) {
      await _log.error('Auto-detect failed: $e');
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  /// Deliberately clear the discovered device list. This is the ONLY way
  /// devices are removed — disconnects, scans, and reconnects never clear it.
  void clearDiscoveredDevices() {
    _discoveredDevices.clear();
    _selectedRemoteUID = null;
    _nextChannelIndex = 1;
    notifyListeners();
  }

  /// Register or update a discovered device. If the UID is new, assign it the
  /// next available tracking channel from the channel preset list.
  void _mergeDevice(String uid, int rssi) {
    final existing = _discoveredDevices[uid];
    if (existing != null) {
      existing.rssi = rssi;
    } else {
      // Assign a unique tracking channel (channels 1-24; 0 is discovery).
      final chIndex = _nextChannelIndex;
      _nextChannelIndex = (_nextChannelIndex % 24) + 1; // wrap 1→24
      final preset = channelPresets[chIndex];
      _discoveredDevices[uid] = DiscoveredDevice(
        uid: uid,
        rssi: rssi,
        trackingConfig: preset.config,
        channelName: preset.name,
      );
      _log.info('Assigned $uid → ${preset.name}');
    }
  }

  Future<void> startScan() async {
    if (!isConnected || isScanning) return;

    _transition(TrackerState.scanning);

    final ok = await _gs.scan();
    if (!ok) {
      _transition(TrackerState.idle);
      return;
    }

    // Poll D every 2 seconds
    _startPolling(
      interval: const Duration(seconds: 2),
      action: _pollDiscovery,
    );
  }

  void stopScan() {
    if (!isScanning) return;
    _stopPolling();
    _transition(TrackerState.idle);
  }

  Future<void> _pollDiscovery() async {
    final result = await _gs.pollDiscovery();

    if (result is DiscoveryCompleteResponse) {
      _stopPolling();
      // Merge new devices into the existing map — update RSSI for known
      // devices, add newly discovered ones, but never remove entries.
      for (final device in result.devices) {
        _mergeDevice(device.uid, device.rssi);
      }
      await _log.info('Discovery complete: ${result.count} device(s)');
      notifyListeners();

      // Loop: restart scan while still in the scanning state
      if (_state == TrackerState.scanning && isConnected) {
        final ok = await _gs.scan();
        if (ok) {
          _startPolling(
            interval: const Duration(seconds: 2),
            action: _pollDiscovery,
          );
        } else {
          _transition(TrackerState.idle);
        }
      }
    } else if (result is DiscoveryWaitResponse) {
      await _log.debug('Discovery in progress: ${result.count} so far');
    } else if (result is DiscoveryNoneResponse) {
      _stopPolling();
      await _log.info('Discovery complete: no devices found');
      notifyListeners();

      // Loop: restart scan while still in the scanning state
      if (_state == TrackerState.scanning && isConnected) {
        final ok = await _gs.scan();
        if (ok) {
          _startPolling(
            interval: const Duration(seconds: 2),
            action: _pollDiscovery,
          );
        } else {
          _transition(TrackerState.idle);
        }
      }
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Pairing / Channel Selection
  // ---------------------------------------------------------------------------

  Future<void> selectRemoteUID(String? uid) async {
    if (uid != null && !_discoveredDevices.containsKey(uid)) return;

    _selectedRemoteUID = uid;

    if (uid != null && isConnected) {
      _stopPolling();
      final device = _discoveredDevices[uid]!;

      if (device.isPaired) {
        // Tracker is already transmitting on its tracking channel.
        // Just switch the ground station radio there directly.
        await _log.info(
            'Switching to ${device.channelName} for $uid (found on channel)');
        final ok = await _gs.switchChannel(device.trackingConfig);
        if (!ok) {
          await _log.error('Channel switch failed for $uid');
          _transition(TrackerState.idle);
          notifyListeners();
          return;
        }
        _transition(TrackerState.tracking);
        _startPolling(
          interval: const Duration(seconds: 1),
          action: _pollForTrackingData,
        );
      } else {
        // Tracker was found via discovery scan — it's on the discovery
        // channel, so we need to PAIR to negotiate a tracking channel.
        _transition(TrackerState.pairing);
        await _gs.switchChannel(LoraConfig.discovery);
        final ok = await _gs.pair(uid, device.trackingConfig);
        if (!ok) {
          await _log.error('PAIR command rejected for $uid');
          _transition(TrackerState.idle);
          notifyListeners();
          return;
        }
        await _log.info('PAIR sent to $uid, waiting for ACK...');

        // Capture stale R baseline so _pollRemote can detect fresh packets
        _pairingBaseline = await _gs.readRemoteRaw();

        _startPolling(
          interval: const Duration(seconds: 1),
          action: _pollForTrackingData,
        );
      }
    } else if (uid == null && isConnected) {
      // Unpair
      _stopPolling();
      _tracker.resetRemoteTracking();
      await _gs.switchChannel(LoraConfig.discovery);
      _transition(TrackerState.idle);
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Tracking poll
  // ---------------------------------------------------------------------------

  /// Combined poll that handles both the pairing→tracking transition
  /// and steady-state tracking data.
  int _pollPhase = 0; // alternates between R and L

  Future<void> _pollForTrackingData() async {
    if (_pollPhase % 2 == 0) {
      // Poll R (remote data)
      await _pollRemote();
    } else {
      // Poll L (local GPS)
      await _pollLocal();
    }
    _pollPhase++;
  }

  Future<void> _pollRemote() async {
    // During pairing, use raw string comparison to detect fresh packets.
    // The ground station caches the last R response and it persists across
    // channel switches, so stale data would falsely trigger tracking.
    if (_state == TrackerState.pairing) {
      final raw = await _gs.readRemoteRaw();
      if (raw == null || raw == _pairingBaseline) return; // stale — ignore

      // Response changed — a fresh packet arrived, parse it
      _pairingBaseline = null; // no longer needed
      final result = _gs.parseRemote(raw);

      if (result is PairAckResponse) {
        await _log.info('PAIR ACK from ${result.remoteId}');
        _discoveredDevices[result.remoteId]?.isPaired = true;
        _transition(TrackerState.tracking);
      } else if (result is RemoteResponse) {
        _mergeDevice(result.remoteId, result.rssi);
        if (_selectedRemoteUID == null ||
            result.remoteId == _selectedRemoteUID) {
          _tracker.updateRemote(result);
          _discoveredDevices[result.remoteId]?.isPaired = true;
          _transition(TrackerState.tracking);
        }
      } else if (result is RemoteUIDResponse) {
        _mergeDevice(result.remoteId, result.rssi);
        if (_selectedRemoteUID == null ||
            result.remoteId == _selectedRemoteUID) {
          _tracker.updateRemoteUid(result);
          _discoveredDevices[result.remoteId]?.isPaired = true;
          _transition(TrackerState.tracking);
        }
      }
      notifyListeners();
      return;
    }

    // Steady-state tracking — no stale-detection needed
    final result = await _gs.readRemote();
    if (result == null) return;

    if (result is RemoteResponse) {
      _mergeDevice(result.remoteId, result.rssi);
      if (_selectedRemoteUID == null ||
          result.remoteId == _selectedRemoteUID) {
        _tracker.updateRemote(result);
      }
    } else if (result is RemoteUIDResponse) {
      _mergeDevice(result.remoteId, result.rssi);
      if (_selectedRemoteUID == null ||
          result.remoteId == _selectedRemoteUID) {
        _tracker.updateRemoteUid(result);
      }
    } else if (result is VoltageResponse) {
      await _log.info(
          'Voltage from ${result.remoteId}: ${result.millivolts} mV');
    }

    notifyListeners();
  }

  Future<void> _pollLocal() async {
    final result = await _gs.readLocal();
    if (result is LocalResponse) {
      _tracker.updateLocal(result);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<bool> uploadSettings() async {
    return await _settings.uploadToDevice();
  }

  Future<void> factoryReset() async {
    await _gs.factoryReset();
  }

  void applyChannelPreset(ChannelPreset preset) {
    _settings.applyChannelPreset(preset);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Channel Scan — sweep channels 1-24 listening for active trackers
  // ---------------------------------------------------------------------------

  /// Start a channel scan. Iterates channels 1–24, switches the radio to each
  /// for ~2 seconds, and polls `R` to detect any transmitting tracker.
  /// Loops continuously until stopped or another function takes over.
  Future<void> startChannelScan() async {
    if (!isConnected || _state == TrackerState.channelScanning) return;

    // Stop any active discovery polling first
    _stopPolling();
    _channelScanResults.clear();
    _channelScanTotal = channelPresets.length - 1; // channels 1-24
    _channelScanCurrent = 0;
    _transition(TrackerState.channelScanning);

    await _log.info('Channel scan started (${_channelScanTotal} channels)');

    while (_state == TrackerState.channelScanning && isConnected) {
      for (int i = 1; i < channelPresets.length; i++) {
        if (_state != TrackerState.channelScanning || !isConnected) break;

        final preset = channelPresets[i];
        _channelScanCurrent = i;
        notifyListeners();

        // Switch to this channel
        final ok = await _gs.switchChannel(preset.config);
        if (!ok) {
          await _log.warning('Failed to switch to ${preset.name}');
          continue;
        }

        // Capture the stale R response as a baseline. The ground station
        // caches the last received packet and a channel switch does NOT
        // clear it. We can only detect a fresh reception by noticing the
        // raw response string has changed.
        final baseline = await _gs.readRemoteRaw();

        // Poll R several times over ~2 seconds
        for (int poll = 0; poll < 4; poll++) {
          if (_state != TrackerState.channelScanning || !isConnected) break;
          await Future.delayed(const Duration(milliseconds: 500));

          final raw = await _gs.readRemoteRaw();
          if (raw == null || raw == baseline) continue; // stale — skip

          // Response changed — a fresh packet arrived on this channel
          final result = _gs.parseRemote(raw);
          if (result is RemoteResponse) {
            _channelScanResults[result.remoteId] = ChannelScanHit(
              uid: result.remoteId,
              rssi: result.rssi,
              channelIndex: i,
              channelName: preset.name,
              config: preset.config,
            );
            await _log.info(
                'Channel scan: found ${result.remoteId} on ${preset.name} '
                '(RSSI ${result.rssi})');
            notifyListeners();
          } else if (result is RemoteUIDResponse) {
            _channelScanResults[result.remoteId] = ChannelScanHit(
              uid: result.remoteId,
              rssi: result.rssi,
              channelIndex: i,
              channelName: preset.name,
              config: preset.config,
            );
            await _log.info(
                'Channel scan: found ${result.remoteId} on ${preset.name} '
                '(RSSI ${result.rssi})');
            notifyListeners();
          }
        }
      }

      if (_state == TrackerState.channelScanning && isConnected) {
        await _log.info(
            'Channel scan sweep complete: '
            '${_channelScanResults.length} tracker(s) found, restarting...');
      }
    }

    // Return to discovery channel when done
    if (isConnected) {
      await _gs.switchChannel(LoraConfig.discovery);
    }
    // Only transition to idle if we're still in channelScanning
    // (another function may have already changed the state)
    if (_state == TrackerState.channelScanning) {
      _transition(TrackerState.idle);
    }
  }

  /// Stop a running channel scan.
  void stopChannelScan() {
    if (_state != TrackerState.channelScanning) return;
    // Transition away — the scan loop checks state and will break out.
    _transition(TrackerState.idle);
  }

  /// Add a tracker found during channel scan to the discovered devices list,
  /// using the channel it was found on as its tracking config.
  void adoptChannelScanHit(String uid) {
    final hit = _channelScanResults[uid];
    if (hit == null) return;

    final existing = _discoveredDevices[uid];
    if (existing != null) {
      // Already known — just update RSSI
      existing.rssi = hit.rssi;
    } else {
      _discoveredDevices[uid] = DiscoveredDevice(
        uid: uid,
        rssi: hit.rssi,
        trackingConfig: hit.config,
        channelName: hit.channelName,
        isPaired: true,
      );
      _log.info('Adopted $uid from channel scan (${hit.channelName})');
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Terminal (raw command for debug screen)
  // ---------------------------------------------------------------------------

  Future<String> sendRawCommand(String command) async {
    return await _gs.sendRawString(command);
  }

  // ---------------------------------------------------------------------------
  // Voltage request
  // ---------------------------------------------------------------------------

  Future<void> requestVoltage(String uid) async {
    await _gs.transmitRaw('&${uid}V');
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _transition(TrackerState newState) {
    if (_state == newState) return;
    final from = _state.name;
    _state = newState;
    _log.state(from, newState.name);
    notifyListeners();
  }

  void _handleDisconnection() {
    _connectInProgress = false;
    _stopPolling();
    _tracker.resetRemoteTracking();
    _transition(TrackerState.disconnected);
  }

  void _startPolling({
    required Duration interval,
    required Future<void> Function() action,
  }) {
    _stopPolling();
    _pollPhase = 0;
    _pollTimer = Timer.periodic(interval, (_) async {
      if (!isConnected) {
        _stopPolling();
        return;
      }
      await action();
    });

    // Refresh the UI every second so time-dependent values
    // (e.g. "Last Packet Age", isRemoteOnline) stay current.
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = null;
  }

  void _startPortScanner() {
    _portScanTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final currentPorts = await _gs.listPorts();

        final changed = !_listEquals(currentPorts, _availablePorts);
        final selectedStillExists =
            _selectedPort == null || currentPorts.contains(_selectedPort);

        if (changed || !selectedStillExists) {
          _availablePorts = currentPorts;

          if (!selectedStillExists) {
            _selectedPort = null;
            if (isConnected) {
              // Port vanished while connected — clean disconnect.
              // Don't call _handleDisconnection separately; disconnect()
              // handles everything including _gs.disconnect().
              disconnect();
            }
          }
          notifyListeners();
        }

        // Auto-connect if disconnected and no connect already in progress
        if (_state == TrackerState.disconnected && !_connectInProgress) {
          await autoDetectAndConnect();
        }
      } catch (e) {
        debugPrint('Port scanner error: $e');
      }
    });
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _portScanTimer?.cancel();
    _stopPolling();
    _uiRefreshTimer?.cancel();
    _gs.dispose();
    super.dispose();
  }
}
