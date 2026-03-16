import 'dart:async';
import 'package:flutter/foundation.dart';
import '../logic/serial_handler.dart';
import '../logic/serial_command_queue.dart';
import '../models/tracker_data.dart';
import '../models/lora_config.dart';
import 'serial_transport.dart';
import 'logging_service.dart';

/// High-level, typed async API for communicating with a SimpleTracker ground
/// station over USB serial.
///
/// Each public method maps to one command from COMMUNICATION_SPEC.md.
/// The class owns the [SerialTransport] and [SerialCommandQueue], handles
/// line-level framing, and returns strongly-typed response objects.
class GroundStationService {
  final SerialTransport _transport = SerialTransport();
  final SerialHandler _handler = SerialHandler();
  late final SerialCommandQueue _commandQueue;
  final LoggingService _log;

  bool _isConnected = false;
  String? _groundStationUid;
  String? _lastRawRemote; // tracks last R response for stale detection

  /// Callbacks for higher layers (provider) to react to events.
  void Function(Object error)? onError;
  VoidCallback? onDisconnected;

  bool get isConnected => _isConnected && _transport.isOpen;
  String? get groundStationUid => _groundStationUid;

  GroundStationService({required LoggingService log}) : _log = log {
    _commandQueue = SerialCommandQueue(sendCommand: _sendRaw);
    _transport.onDataReceived = _onDataReceived;
    _transport.onError = _onTransportError;
    _transport.onDone = _onTransportDone;
  }

  // ---------------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------------

  /// List available serial ports.
  Future<List<String>> listPorts() => _transport.listPorts();

  /// Get device info for a port.
  Future<SerialDeviceInfo?> getDeviceInfo(String portName) =>
      _transport.getDeviceInfo(portName);

  /// Find all connected SimpleTracker devices.
  Future<List<SerialDeviceInfo>> getSimpleTrackerDevices() =>
      _transport.getSimpleTrackerDevices();

  /// Open [portName] and query the ground station UID.
  /// Returns the UID string on success, null on failure.
  Future<String?> connect(String portName) async {
    try {
      _isConnected = await _transport.openPort(portName, 115200);
      if (!_isConnected) return null;

      _transport.flushInputBuffer();
      await _log.info('Connected to $portName');

      // Query UID
      final uidResult = await getUid();
      if (uidResult != null) {
        _groundStationUid = uidResult;
        await _log.info('Ground station UID: $uidResult');
      }
      return _groundStationUid;
    } catch (e) {
      await _log.error('Connect failed: $e');
      return null;
    }
  }

  /// Close the serial connection.
  Future<void> disconnect() async {
    if (!_isConnected) return; // already disconnected — idempotent
    _isConnected = false;
    _groundStationUid = null;
    _lastRawRemote = null;
    _commandQueue.failAll(StateError('Disconnect requested'));
    try {
      await _transport.closePort();
    } catch (e) {
      debugPrint('Error closing port: $e');
    }
    await _log.info('Disconnected');
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    _commandQueue.failAll(StateError('Service disposed'));
    try {
      await _transport.disposeService();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Command API (mirrors COMMUNICATION_SPEC.md §2)
  // ---------------------------------------------------------------------------

  /// §2.1 — Get ground station UID.
  Future<String?> getUid() async {
    final response = await _sendCommand('UID');
    if (response == null) return null;
    final result = _handler.parse('UID', response);
    if (result is UidResponse) return result.uid;
    return null;
  }

  /// §2.2 — Initiate device discovery scan.
  Future<bool> scan() async {
    final response = await _sendCommand('SCAN');
    if (response == null) return false;
    final result = _handler.parse('SCAN', response);
    return result is CommandStatus && result.response == 'OK';
  }

  /// §2.3 — Poll discovery results.
  /// Returns a [DiscoveryNoneResponse], [DiscoveryWaitResponse], or
  /// [DiscoveryCompleteResponse].
  Future<dynamic> pollDiscovery() async {
    final response = await _sendCommand('D');
    if (response == null) return DiscoveryNoneResponse();
    return _handler.parse('D', response);
  }

  /// §2.4 — Pair with a remote tracker.
  Future<bool> pair(String uid, LoraConfig config) async {
    final cmd = 'PAIR $uid ${config.toParams()}';
    final response = await _sendCommand(cmd);
    if (response == null) return false;
    final result = _handler.parse(cmd, response);
    return result is CommandStatus && result.response == 'OK';
  }

  /// §2.6 — Read last received LoRa message.
  /// Returns a typed response (RemoteResponse, PairAckResponse, etc.)
  /// or null if empty / unchanged since last call.
  Future<dynamic> readRemote() async {
    final raw = await _sendCommand('R');
    if (raw == null || raw == _lastRawRemote) return null;
    _lastRawRemote = raw;
    return _handler.parse('R', raw);
  }

  /// Reset the stale-detection baseline. Call this after a channel switch
  /// or before starting pairing so the next readRemote() doesn't compare
  /// against a response from a different context.
  void resetRemoteBaseline() {
    _lastRawRemote = null;
  }

  /// §2.7 — Read local GPS sentence.
  Future<dynamic> readLocal() async {
    final response = await _sendCommand('L');
    if (response == null) return null;
    return _handler.parse('L', response);
  }

  /// §2.8 — Switch the ground station radio channel.
  Future<bool> switchChannel(LoraConfig config) async {
    final cmd = 'C ${config.toParams()}';
    final response = await _sendCommand(cmd);
    if (response == null) return false;
    final result = _handler.parse(cmd, response);
    return result is CommandStatus && result.response == 'OK';
  }

  /// §2.5 — Send a raw LoRa transmission.
  Future<bool> transmitRaw(String payload) async {
    final cmd = 'T $payload';
    final response = await _sendCommand(cmd);
    if (response == null) return false;
    final result = _handler.parse(cmd, response);
    return result is CommandStatus && result.response == 'OK';
  }

  /// §2.9 — Get a device setting.
  Future<int?> getSetting(String key) async {
    final cmd = 'GET $key';
    final response = await _sendCommand(cmd);
    if (response == null) return null;
    final result = _handler.parse(cmd, response);
    if (result is SettingResponse) return result.value;
    return null;
  }

  /// §2.9 — Set a device setting.
  Future<bool> setSetting(String key, int value) async {
    final cmd = 'SET $key $value';
    final response = await _sendCommand(cmd);
    if (response == null) return false;
    final result = _handler.parse(cmd, response);
    return result is CommandStatus && result.response == 'OK';
  }

  /// §2.10 — Reboot the device.
  Future<void> reboot() async {
    await _sendCommand('REBOOT', expectResponse: false);
  }

  /// §2.11 — Factory reset.
  Future<void> factoryReset() async {
    await _sendCommand('FACTORY', expectResponse: false);
  }

  /// Send an arbitrary command string (for the terminal screen).
  /// Returns the raw response string.
  Future<String> sendRawString(String command) async {
    return await _sendCommand(command) ?? '';
  }

  // ---------------------------------------------------------------------------
  // Internal plumbing
  // ---------------------------------------------------------------------------

  /// Send a command through the queue and return the raw response.
  Future<String?> _sendCommand(String command,
      {bool expectResponse = true}) async {
    if (!isConnected) return null;
    try {
      final cmdWithNewline =
          command.endsWith('\n') ? command : '$command\n';
      await _log.serial('> ${command.trim()}');
      final response = await _commandQueue.enqueue(cmdWithNewline,
          expectResponse: expectResponse);
      return response;
    } catch (e) {
      await _log.error('Command failed [$command]: $e');
      return null;
    }
  }

  /// Low-level send (called by SerialCommandQueue).
  Future<void> _sendRaw(String command) async {
    if (!_isConnected) return;
    _transport.send(command);
  }

  /// Handle incoming serial data.
  void _onDataReceived(String raw) async {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return;
    await _log.serial('< $cleaned');
    _commandQueue.handleIncomingResponse(cleaned);
  }

  void _onTransportError(Object error) {
    _log.error('Transport error: $error');
    _handleTermination(error);
  }

  void _onTransportDone() {
    _log.error('Transport stream closed');
    _handleTermination(StateError('Serial stream closed'));
  }

  void _handleTermination(Object cause) {
    if (!_isConnected) return; // already handled — avoid double-fire
    _isConnected = false;
    _groundStationUid = null;
    _lastRawRemote = null;
    _commandQueue.failAll(StateError('Connection lost: $cause'));
    try {
      _transport.closePort();
    } catch (_) {}
    onDisconnected?.call();
  }
}
