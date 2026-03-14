import 'package:flutter/material.dart';
import '../logic/telemetry_tracker.dart';
import '../services/serial_service.dart';
import '../services/logging_service.dart';
import '../logic/serial_handler.dart';
import '../models/tracker_data.dart';
import '../models/telemetry_model.dart';
import '../models/command_model.dart';
import '../logic/serial_poller.dart';
import '../settings.dart';
import '../logic/serial_command_queue.dart';
import 'dart:async';

class SerialProvider extends ChangeNotifier {
  final SerialService _serial = SerialService();
  final LoggingService _logger = LoggingService();
  final SerialHandler _handler = SerialHandler();

  bool _isConnected = false;
  final List<Command> commandQueue = [];
  final TelemetryTracker _tracker = TelemetryTracker();
  bool get remotePacketHasFix => _tracker.lastPacketHadFix;
  String? _remoteId;
  String? _groundStationUid;
  Timer? _portScanTimer;
  List<String> _availablePorts = [];
  String? _selectedPort;
  late SerialPoller _poller;
  late final SerialCommandQueue _commandQueue;

  // Remote UID discovery and selection
  final Map<String, int> _discoveredDevices = {}; // uid -> rssi
  String? _selectedRemoteUID;
  bool _isScanning = false;
  bool _isPaired = false;

  /// UIDs of all remote trackers detected during discovery
  Set<String> get discoveredUIDs =>
      Set.unmodifiable(_discoveredDevices.keys.toSet());

  /// Map of discovered device UIDs to their RSSI values
  Map<String, int> get discoveredDevices =>
      Map.unmodifiable(_discoveredDevices);

  /// Currently selected remote tracker UID (null = none selected)
  String? get selectedRemoteUID => _selectedRemoteUID;

  /// Whether a SCAN is in progress
  bool get isScanning => _isScanning;

  /// Whether we are currently paired with a remote tracker
  bool get isPaired => _isPaired;

  /// Ground station UID
  String? get groundStationUid => _groundStationUid;

  /// Expose telemetry from the tracker (used by UI)
  TelemetryModel? get telemetry => _tracker.telemetry;

  /// True when we've received recent/new remote responses (not stuck on identical responses)
  bool get isRemoteOnline => _tracker.isRemoteOnline && _isConnected;

  /// Get the timestamp of the last unique remote packet received
  DateTime? get lastUniqueRemotePacketTime =>
      _tracker.lastUniqueRemotePacketTime;

  // Public state getters
  bool get isConnected => _isConnected && _serial.isOpen;
  List<String> get logs => List.unmodifiable(_logger.log);
  String? get remoteId => _remoteId;
  Map<String, Setting> get settings => Map.unmodifiable(defaultSettings);
  List<String> get availablePorts => _availablePorts;
  String? get selectedPort => _selectedPort;
  String? get logFilePath => _logger.currentLogPath;
  bool get isPolling => _poller.isPolling;

  void startPolling() {
    _poller.start();
    notifyListeners();
  }

  void stopPolling() {
    _poller.stop();
    notifyListeners();
  }

  void selectPort(String? port) {
    _selectedPort = port;
    notifyListeners();
  }

  /// Automatically detect and connect to the first SimpleTracker ground station.
  /// Returns true if auto-connected successfully, false if manual selection needed or error occurred.
  Future<bool> autoDetectAndConnect() async {
    try {
      final simpleTrackers = await _serial.getSimpleTrackerDevices();

      if (simpleTrackers.isEmpty) {
        debugPrint('autoDetectAndConnect: No SimpleTracker devices found');
        return false;
      }

      if (simpleTrackers.length == 1) {
        // Exactly one device found, auto-connect
        final device = simpleTrackers.first;
        debugPrint(
            'autoDetectAndConnect: Found single SimpleTracker at ${device.portName}');
        selectPort(device.portName);
        await connect();
        return true;
      }

      if (simpleTrackers.length > 1) {
        // Multiple devices found, require manual selection
        debugPrint(
            'autoDetectAndConnect: Found ${simpleTrackers.length} SimpleTracker devices, manual selection required');
        return false;
      }
    } catch (e) {
      debugPrint('autoDetectAndConnect error: $e');
    }
    return false;
  }

  /// Select a remote tracker by UID and initiate pairing via the PAIR command.
  /// Uses a dedicated tracking channel offset from the discovery channel.
  /// Pass null to unpair and return to the discovery channel.
  void selectRemoteUID(String? uid) {
    if (uid != null && !_discoveredDevices.containsKey(uid)) {
      debugPrint('selectRemoteUID: UID $uid not in discovered set');
      return;
    }
    _selectedRemoteUID = uid;

    // If a UID is selected, send the PAIR command and switch to tracking mode
    if (uid != null && _isConnected) {
      // Stop any in-progress scan
      _isScanning = false;
      _poller.stop();

      // Use a dedicated tracking channel (offset from discovery)
      final trackingFreq = 434500000; // 434.5 MHz
      final trackingSf = 9;
      final trackingBw = 4; // 125 kHz

      final pairCmd = 'PAIR $uid $trackingFreq $trackingSf $trackingBw\n';
      debugPrint('Pairing with remote tracker: $pairCmd');
      try {
        sendQueuedCommand(pairCmd);
      } catch (e) {
        debugPrint('Error sending PAIR command: $e');
      }

      // Switch poller to tracking mode: poll R for GPS data and L for local GPS
      _poller.configure(commands: [
        PollCommand(command: "L\n", delay: Duration(seconds: 1)),
        PollCommand(command: "R\n", delay: Duration(seconds: 1)),
      ]);

      _isPaired = true;
    } else if (uid == null && _isConnected) {
      _isPaired = false;
      _poller.stop();
      _tracker.resetRemoteTracking();
      // Switch ground station back to discovery channel, then restart scanning
      _switchToDiscoveryChannel().then((_) {
        _startDiscoveryPolling();
      });
    }

    notifyListeners();
  }

  /// Send a SCAN command and start polling D for results.
  /// If [preserveList] is true, the current discovered devices are kept visible
  /// until the new scan completes (used for continuous auto-scanning).
  Future<void> startScan({bool preserveList = false}) async {
    if (!_isConnected) return;

    _isScanning = true;
    if (!preserveList) {
      _discoveredDevices.clear();
    }
    notifyListeners();

    try {
      // Stop any current polling
      _poller.stop();

      // Send SCAN command
      await sendQueuedCommand("SCAN\n");

      // Poll D for results using the poller
      _poller.configure(commands: [
        PollCommand(command: "D\n", delay: Duration(seconds: 2)),
      ]);
    } catch (e) {
      debugPrint('Error starting scan: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Switch ground station back to the discovery channel
  Future<void> _switchToDiscoveryChannel() async {
    try {
      await sendQueuedCommand("C 434000000 9 4\n");
    } catch (e) {
      debugPrint('Error switching to discovery channel: $e');
    }
  }

  /// Start discovery polling (SCAN + D cycle)
  void _startDiscoveryPolling() {
    startScan();
  }

  /// Request battery voltage from a specific tracker (before pairing, on discovery channel)
  Future<void> requestVoltage(String uid) async {
    if (!_isConnected) return;
    try {
      await sendQueuedCommand("T &${uid}V\n");
    } catch (e) {
      debugPrint('Error requesting voltage: $e');
    }
  }

  /// Clear discovery and reset selected UID
  void _clearRemoteDiscovery() {
    _discoveredDevices.clear();
    _selectedRemoteUID = null;
    _isScanning = false;
    _isPaired = false;
  }

  Future<void> connect() async {
    if (selectedPort != null) {
      try {
        // Reset discovery on new connect
        _clearRemoteDiscovery();
        _isConnected = await _serial.openPort(_selectedPort!, 115200);
        if (_isConnected) {
          // successful connect; normal startup
          _serial.flushInputBuffer();
          try {
            // Get ground station UID
            await sendQueuedCommand("UID\n");
          } catch (e) {
            debugPrint("Failed to send initial command: $e");
          }
          await loadSettings();
          // Ensure we're on the discovery channel, then start scanning
          await _switchToDiscoveryChannel();
          _startDiscoveryPolling();
        }
        notifyListeners();
      } catch (e) {
        debugPrint("SerialPortError on connect(): $e");
      }
    }
  }

  Future<void> loadSettings() async {
    for (var entry in settings.entries) {
      final String commandChar = entry.key;

      try {
        await sendQueuedCommand("GET $commandChar\n");
      } catch (e) {
        debugPrint("Failed to load $commandChar: $e");
      }
    }
    notifyListeners();
  }

  void disconnect() {
    // user-initiated disconnect: stop poller and close port
    _poller.stop();
    _tracker.resetRemoteTracking();
    try {
      _serial.closePort();
    } catch (e) {
      debugPrint('Error closing port in disconnect(): $e');
    }
    _isConnected = false;
    notifyListeners();
  }

  void _handleSerialDone() {
    debugPrint('Serial port stream done');
    _handleSerialTermination(StateError('Serial stream closed'));
  }

  void _handleSerialError(Object error) {
    debugPrint('Serial port stream error: $error');
    _handleSerialTermination(error);
  }

  void _handleIncomingData(String raw) async {
    final cleaned = raw.trim();
    final logLine = "< $cleaned";
    await _logger.append(logLine);

    final commandContext = _commandQueue.handleIncomingResponse(cleaned);
    if (commandContext == null) return;

    final result = _handler.parse(commandContext.trim(), cleaned);

    if (result is UidResponse) {
      _groundStationUid = result.uid;
      debugPrint('Ground Station UID: ${result.uid}');
    } else if (result is LocalResponse) {
      _tracker.updateLocal(result);
    } else if (result is RemoteResponse) {
      // Track the remote device
      _discoveredDevices[result.remoteId] = result.rssi;

      // Filter by selected UID if one is selected
      if (_selectedRemoteUID != null && result.remoteId != _selectedRemoteUID) {
        // UID doesn't match; ignore this response
        notifyListeners();
        return;
      }
      // Update telemetry model
      _tracker.updateRemote(result);
      notifyListeners();
      return;
    } else if (result is RemoteUIDResponse) {
      // UID + RSSI only (no valid GPS fix in this packet)
      _discoveredDevices[result.remoteId] = result.rssi;

      if (_selectedRemoteUID != null && result.remoteId != _selectedRemoteUID) {
        notifyListeners();
        return;
      }
      _tracker.updateRemoteUid(result);
      notifyListeners();
      return;
    } else if (result is DiscoveryCompleteResponse) {
      // Scan is complete — update discovered devices
      _discoveredDevices.clear();
      for (final device in result.devices) {
        _discoveredDevices[device.uid] = device.rssi;
      }
      _isScanning = false;
      // Stop polling D now that scan is complete
      _poller.stop();
      debugPrint('Discovery complete: ${result.count} device(s) found');
      // Auto-restart scan if no tracker is paired
      if (!_isPaired && _selectedRemoteUID == null) {
        startScan(preserveList: true);
      }
    } else if (result is DiscoveryWaitResponse) {
      // Scan still in progress, keep polling
      debugPrint('Discovery in progress: ${result.count} device(s) so far');
    } else if (result is DiscoveryNoneResponse) {
      // No scan initiated — restart scan if not paired
      _isScanning = false;
      _poller.stop();
      if (!_isPaired && _selectedRemoteUID == null) {
        startScan(preserveList: true);
      }
    } else if (result is PairAckResponse) {
      debugPrint('PAIR ACK received from ${result.remoteId}');
      _remoteId = result.remoteId;
      _isPaired = true;
    } else if (result is VoltageResponse) {
      debugPrint('Voltage from ${result.remoteId}: ${result.millivolts} mV');
    } else if (result is SettingResponse) {
      if (settings[result.key] != null) {
        settings[result.key]!.value = result.value;
        settings[result.key]!.initialValue =
            result.value; // Update initialValue to match loaded value
      }
    } else if (result is CommandStatus) {
      debugPrint('Command response: ${result.response}');
    }

    notifyListeners();
  }

  void _handleSerialTermination(Object cause) {
    debugPrint('Serial terminated: $cause');

    // stop periodic work and mark disconnected
    _poller.stop();
    _tracker.resetRemoteTracking();
    _isConnected = false;

    // Clear discovery on termination
    _clearRemoteDiscovery();

    // Fail any queued commands so callers don't hang
    _commandQueue.failAll(StateError('Serial connection terminated: $cause'));

    // Close low-level resources (safe to call even if already closed)
    try {
      _serial.closePort();
    } catch (e) {
      debugPrint('Error during serial termination cleanup: $e');
    }

    // no auto-reconnect: user must reconnect manually

    // notify UI
    notifyListeners();
  }

  Future<String> sendQueuedCommand(String command,
      {bool expectResponse = true}) async {
    try {
      var response =
          await _commandQueue.enqueue(command, expectResponse: expectResponse);
      return response;
    } catch (e) {
      debugPrint("Error sending command: $e");
      return '';
    }
  }

  Future<void> _sendRawCommand(String command) async {
    if (!_isConnected) return;

    try {
      commandQueue.add(Command(command.trim()));
      _serial.send(command);
      final logLine = "> $command".trim();
      await _logger.append(logLine);
      notifyListeners();
    } catch (e) {
      debugPrint("SerialPortError on send(): $e");
      disconnect();
    }
  }

  void _startPortScanner() {
    // periodic background monitor — uses async callback to perform up-to-date scans
    _portScanTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final currentPorts = await _serial.listPorts();

        // Check if port list has changed
        final portListChanged = !_listEquals(currentPorts, _availablePorts);

        // Check if selected port is still valid
        final selectedPortStillExists =
            _selectedPort == null || currentPorts.contains(_selectedPort);

        if (portListChanged || !selectedPortStillExists) {
          _availablePorts = currentPorts;

          if (!selectedPortStillExists) {
            // Clean up connection and reset selected port
            _selectedPort = null;

            if (_isConnected) {
              try {
                await _serial.closePort();
              } catch (e) {
                debugPrint('Error closing port: $e');
              } finally {
                _isConnected = false;
              }
            }
          }

          notifyListeners(); // Trigger UI rebuild
        }

        // If not currently connected, try auto-detecting SimpleTracker devices
        if (!_isConnected) {
          await autoDetectAndConnect();
        }
      } catch (e) {
        debugPrint('Port scanner error: $e');
      }
    });
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  SerialProvider() {
    _commandQueue = SerialCommandQueue(
      sendCommand: _sendRawCommand,
    );
    _poller = SerialPoller(serial: this);
    _logger.init().then((_) {
      notifyListeners(); // Notify UI once log file is ready
    });
    _serial.onDataReceived = _handleIncomingData;
    _serial.onError = _handleSerialError;
    _serial.onDone = _handleSerialDone;
    _startPortScanner();
  }

  @override
  void dispose() {
    _portScanTimer?.cancel();
    _poller.stop();
    try {
      _serial.disposeService();
    } catch (_) {}
    super.dispose();
  }
}
