import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

// Desktop serial (linux/mac/windows) plugin
import 'package:flutter_libserialport/flutter_libserialport.dart'
    if (dart.library.html) 'unsupported_stub.dart';

// Android serial plugin (usb_serial: ^0.5.2)
import 'package:usb_serial/usb_serial.dart';

/// Device information for serial ports
class SerialDeviceInfo {
  final String portName;
  final String? productName;
  final String? manufacturerName;
  final int? vendorId;
  final int? productId;
  final String? serialNumber;

  SerialDeviceInfo({
    required this.portName,
    this.productName,
    this.manufacturerName,
    this.vendorId,
    this.productId,
    this.serialNumber,
  });

  /// Check if this is a SimpleTracker device (VID=0xcafe, PID=0x4000 or Product="SimpleTracker")
  bool get isSimpleTracker {
    // Check by VID/PID
    if (vendorId == 0xcafe && productId == 0x4000) {
      return true;
    }
    // Check by product name
    if (productName?.toLowerCase().contains('simpletracker') ?? false) {
      return true;
    }
    return false;
  }

  @override
  String toString() =>
      '$portName (${productName ?? manufacturerName ?? 'Unknown'})';
}

/// Cross-platform serial service facade.
/// - onDataReceived(String) callback receives decoded incoming data
/// - onError and onDone notify higher layers
class SerialTransport {
  void Function(Object error)? onError;
  VoidCallback? onDone;
  void Function(String)? onDataReceived;

  final Utf8Decoder _decoder = const Utf8Decoder(allowMalformed: true);
  late final _SerialServiceImpl _impl;

  // Line buffer: accumulate partial data until a full \n-terminated line arrives
  // or a short idle timeout elapses (device responses may not include \n).
  final StringBuffer _lineBuffer = StringBuffer();
  Timer? _lineFlushTimer;
  static const _lineFlushDelay = Duration(milliseconds: 50);

  // cached snapshot of ports for synchronous access
  List<String> _cachedPorts = [];

  /// Synchronous, read-only view of the last-known ports.
  /// Call [listPorts] to refresh the cache from the underlying implementation.
  List<String> get availablePorts => List.unmodifiable(_cachedPorts);

  SerialTransport() {
    if (Platform.isAndroid) {
      _impl = _AndroidSerialImpl(
          _decoder, _forwardData, _forwardError, _forwardDone);
    } else {
      _impl = _DesktopSerialImpl(
          _decoder, _forwardData, _forwardError, _forwardDone);
    }
  }

  /// Refresh the cached ports by querying the platform implementation.
  Future<List<String>> listPorts() async {
    try {
      final ports = await _impl.listPorts();
      _cachedPorts = ports;
      return ports;
    } catch (e) {
      // keep previous cache on error
      debugPrint('listPorts error: $e');
      return _cachedPorts;
    }
  }

  /// Get detailed device information for a specific port.
  Future<SerialDeviceInfo?> getDeviceInfo(String portName) async {
    try {
      return await _impl.getDeviceInfo(portName);
    } catch (e) {
      debugPrint('getDeviceInfo error: $e');
      return null;
    }
  }

  /// Get device info for all ports and filter by SimpleTracker devices.
  Future<List<SerialDeviceInfo>> getSimpleTrackerDevices() async {
    try {
      final ports = await listPorts();
      final devices = <SerialDeviceInfo>[];

      for (final port in ports) {
        final info = await getDeviceInfo(port);
        if (info != null && info.isSimpleTracker) {
          devices.add(info);
        }
      }

      return devices;
    } catch (e) {
      debugPrint('getSimpleTrackerDevices error: $e');
      return [];
    }
  }

  bool get isOpen => _impl.isOpen;

  Future<void> flushInputBuffer() {
    _lineFlushTimer?.cancel();
    _lineBuffer.clear();
    return _impl.flushInputBuffer();
  }

  Future<bool> openPort(String portName, int baudRate) {
    _lineFlushTimer?.cancel();
    _lineBuffer.clear();
    return _impl.openPort(portName, baudRate);
  }

  Future<void> closePort() {
    _lineFlushTimer?.cancel();
    _lineBuffer.clear();
    return _impl.closePort();
  }

  Future<void> send(String data) => _impl.send(data);

  Future<void> disposeService() => _impl.dispose();

  // internal forwards
  /// Buffer incoming data and emit complete \n-terminated lines immediately.
  /// If no \n arrives within a short timeout, flush the buffer as a complete
  /// response (the device may not send a trailing newline).
  void _forwardData(String s) {
    _lineFlushTimer?.cancel();
    _lineBuffer.write(s);
    final buffered = _lineBuffer.toString();

    // Process all complete lines in the buffer
    int start = 0;
    int nlIndex = buffered.indexOf('\n', start);
    while (nlIndex != -1) {
      final line = buffered.substring(start, nlIndex);
      if (line.isNotEmpty) {
        onDataReceived?.call(line);
      }
      start = nlIndex + 1;
      nlIndex = buffered.indexOf('\n', start);
    }

    // Keep any remaining partial data in the buffer
    _lineBuffer.clear();
    if (start < buffered.length) {
      _lineBuffer.write(buffered.substring(start));
      // No \n yet — start a short timer to flush as a complete response
      _lineFlushTimer = Timer(_lineFlushDelay, _flushLineBuffer);
    }
  }

  /// Flush any buffered data as a complete response (timeout-based).
  void _flushLineBuffer() {
    final remaining = _lineBuffer.toString().trim();
    _lineBuffer.clear();
    if (remaining.isNotEmpty) {
      onDataReceived?.call(remaining);
    }
  }

  void _forwardError(Object e) => onError?.call(e);
  void _forwardDone() => onDone?.call();
}

/// Shared impl interface
abstract class _SerialServiceImpl {
  Future<List<String>> listPorts();
  Future<SerialDeviceInfo?> getDeviceInfo(String portName);
  bool get isOpen;
  Future<void> flushInputBuffer();
  Future<bool> openPort(String portName, int baudRate);
  Future<void> closePort();
  Future<void> send(String data);
  Future<void> dispose();
}

/// Desktop implementation using flutter_libserialport
class _DesktopSerialImpl implements _SerialServiceImpl {
  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSubscription;
  final Utf8Decoder _decoder;
  final void Function(String) onData;
  final void Function(Object) onError;
  final VoidCallback onDone;

  _DesktopSerialImpl(this._decoder, this.onData, this.onError, this.onDone);

  @override
  Future<List<String>> listPorts() async {
    try {
      return SerialPort.availablePorts;
    } catch (e) {
      return <String>[];
    }
  }

  @override
  Future<SerialDeviceInfo?> getDeviceInfo(String portName) async {
    try {
      if (!SerialPort.availablePorts.contains(portName)) {
        return null;
      }

      // Create a temporary SerialPort instance to query device info
      final port = SerialPort(portName);
      try {
        return SerialDeviceInfo(
          portName: portName,
          productName: port.productName,
          manufacturerName: port.manufacturer,
          vendorId: port.vendorId,
          productId: port.productId,
          serialNumber: port.serialNumber,
        );
      } finally {
        port.dispose();
      }
    } catch (e) {
      debugPrint('Desktop getDeviceInfo error: $e');
      return null;
    }
  }

  @override
  bool get isOpen => _port?.isOpen ?? false;

  @override
  Future<void> flushInputBuffer() async {
    try {
      if (_port != null) _port!.flush(SerialPortBuffer.input);
    } catch (_) {}
  }

  @override
  Future<bool> openPort(String portName, int baudRate) async {
    try {
      if (!SerialPort.availablePorts.contains(portName)) {
        _port = null;
        return false;
      }
      _port = SerialPort(portName);

      final config = SerialPortConfig()
        ..baudRate = baudRate
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none
        ..setFlowControl(SerialPortFlowControl.none);

      if (!_port!.openReadWrite()) {
        _port = null;
        return false;
      }

      try {
        _port!.config = config;
      } catch (error) {
        debugPrint(error.toString());
      }

      _reader = SerialPortReader(_port!);
      _readerSubscription = _reader!.stream.listen((Uint8List data) {
        final msg = _decoder.convert(data);
        onData(msg);
      }, onError: (err) {
        onError(err!);
      }, onDone: () {
        onDone();
      });

      return true;
    } catch (e) {
      debugPrint('Desktop openPort error: $e');
      return false;
    }
  }

  @override
  Future<void> closePort() async {
    try {
      await _readerSubscription?.cancel();
    } catch (_) {}
    _readerSubscription = null;
    try {
      _reader?.close();
    } catch (_) {}
    try {
      _port?.close();
    } catch (_) {}
    _reader = null;
    _port = null;
  }

  @override
  Future<void> send(String data) async {
    try {
      if (_port?.isOpen ?? false) {
        _port!.write(utf8.encode(data));
      } else {
        onError(StateError('Port not open'));
      }
    } catch (e) {
      onError(e);
    }
  }

  @override
  Future<void> dispose() async {
    await closePort();
    try {
      await _readerSubscription?.cancel();
    } catch (_) {}
    _readerSubscription = null;
  }
}

/// Android implementation using usb_serial 0.5.2
class _AndroidSerialImpl implements _SerialServiceImpl {
  UsbPort? _port;
  StreamSubscription<dynamic>? _inputSub;
  bool _isOpen = false;
  final Utf8Decoder _decoder;
  final void Function(String) onData;
  final void Function(Object) onError;
  final VoidCallback onDone;

  _AndroidSerialImpl(this._decoder, this.onData, this.onError, this.onDone);

  @override
  Future<List<String>> listPorts() async {
    try {
      final devices = await UsbSerial.listDevices();
      return devices.map((d) {
        final name =
            d.productName ?? d.manufacturerName ?? 'device:${d.deviceId}';
        return '${d.deviceId}|$name';
      }).toList();
    } catch (e) {
      debugPrint('Android listPorts error: $e');
      return <String>[];
    }
  }

  @override
  Future<SerialDeviceInfo?> getDeviceInfo(String portName) async {
    try {
      final parts = portName.split('|');
      if (parts.isEmpty) return null;
      final idStr = parts[0];
      final id = int.tryParse(idStr);
      if (id == null) return null;

      final devices = await UsbSerial.listDevices();
      UsbDevice? device;
      try {
        device = devices.firstWhere((d) => d.deviceId == id);
      } catch (e) {
        return null;
      }

      return SerialDeviceInfo(
        portName: portName,
        productName: device.productName,
        manufacturerName: device.manufacturerName,
        vendorId: device.vid,
        productId: device.pid,
        serialNumber: null,
      );
    } catch (e) {
      debugPrint('Android getDeviceInfo error: $e');
      return null;
    }
  }

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> flushInputBuffer() async {
    try {
      await _inputSub?.cancel();
      _inputSub = null;
    } catch (_) {}
  }

  @override
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
        await port.setPortParameters(baudRate, UsbPort.DATABITS_8,
            UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
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
            final bytes = data is Uint8List
                ? data
                : Uint8List.fromList(List<int>.from(data));
            final msg = _decoder.convert(bytes);
            onData(msg);
          } catch (e) {
            // decode error
            debugPrint('Android decode error: $e');
          }
        }, onError: (e) {
          onError(e ?? StateError('Unknown input error'));
        }, onDone: () {
          onDone();
        });
      }

      return true;
    } catch (e) {
      debugPrint('Android openPort error: $e');
      return false;
    }
  }

  @override
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

  @override
  Future<void> send(String data) async {
    try {
      if (_port != null && _isOpen) {
        await _port!.write(Uint8List.fromList(utf8.encode(data)));
      } else {
        onError(StateError('Port not open'));
      }
    } catch (e) {
      onError(e);
    }
  }

  @override
  Future<void> dispose() async {
    await closePort();
    try {
      await _inputSub?.cancel();
    } catch (_) {}
    _inputSub = null;
  }
}
