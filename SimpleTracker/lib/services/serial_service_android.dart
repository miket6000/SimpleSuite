import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

// Android serial plugin (usb_serial: ^0.5.2)
import 'package:usb_serial/usb_serial.dart';

/// Cross-platform serial service facade.
/// - onDataReceived(String) callback receives decoded incoming data
/// - onError and onDone notify higher layers
class SerialService {
  void Function(Object error)? onError;
  VoidCallback? onDone;
  void Function(String)? onDataReceived;

  final Utf8Decoder _decoder = const Utf8Decoder(allowMalformed: true);

  // cached snapshot of ports for synchronous access
  // List<String> _cachedPorts = [];

  /// Synchronous, read-only view of the last-known ports.
  /// Call [listPorts] to refresh the cache from the underlying implementation.
  // List<String> get availablePorts => List.unmodifiable(_cachedPorts);
  UsbPort? _port;
  StreamSubscription<dynamic>? _inputSub;
  bool _isOpen = false;

  Future<List<String>> listPorts() async {
    try {
      final devices = await UsbSerial.listDevices();
      return devices.map((d) {
        final name = d.productName ?? d.manufacturerName ?? 'device:${d.deviceId}';
        return '${d.deviceId}|$name';
      }).toList();
    } catch (e) {
      debugPrint('Android listPorts error: $e');
      return <String>[];
    }
  }

  bool get isOpen => _isOpen;

  Future<void> flushInputBuffer() async {
    try {
      await _inputSub?.cancel();
      _inputSub = null;
    } catch (_) {}
  }


  Future<bool> openPort(String portName, int baudRate) async {
    try {
      final parts = portName.split('|');
      if (parts.isEmpty) return false;
      final idStr = parts[0];
      final id = int.tryParse(idStr);
      if (id == null) return false;

      final devices = await UsbSerial.listDevices();
      final device = devices.firstWhere(
        (d) => d.deviceId == id,
        orElse: () => throw StateError('Device not found'),
      );

      final port = await device.create();
      if (port == null) return false;
      final opened = await port.open();
      if (!opened) return false;

      // Configure 8-N-1
      try {
        await port.setPortParameters(baudRate, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
      } catch (e) {
        debugPrint('Failed to set port params: $e');
      }

      _port = port;
      _isOpen = true;

      // inputStream may be Stream<List<int>> or Stream<Uint8List>
      final input = port.inputStream;
      if (input != null) {
        _inputSub = input.listen((dynamic data) {
          try {
            final bytes = data is Uint8List ? data : Uint8List.fromList(List<int>.from(data));
            final msg = _decoder.convert(bytes);
            onDataReceived!(msg);
          } catch (e) {
            // decode error
            debugPrint('Android decode error: $e');
          }
        }, onError: (e) {
          onError!(e ?? StateError('Unknown input error'));
        }, onDone: () {
          onDone!();
        });
      }

      return true;
    } catch (e) {
      debugPrint('Android openPort error: $e');
      return false;
    }
  }

  Future<void> closePort() async {
    try {
      await _inputSub?.cancel();
    } catch (_) {}
    _inputSub = null;
    try {
      await _port?.close();
    } catch (_) {}
    _port = null;
    _isOpen = false;
  }

  Future<void> send(String data) async {
    try {
      if (_port != null && _isOpen) {
        await _port!.write(Uint8List.fromList(utf8.encode(data)));
      } else {
        onError!(StateError('Port not open'));
      }
    } catch (e) {
      onError!(e);
    }
  }

  Future<void> dispose() async {
    await closePort();
    try {
      await _inputSub?.cancel();
    } catch (_) {}
    _inputSub = null;
  }
}

