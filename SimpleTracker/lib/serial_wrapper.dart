import 'dart:async';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter/foundation.dart';


class SerialPortWrapper {
  final String portName;
  final int baudRate;
  SerialPort? _port;
  static List<String> get availablePorts => SerialPort.availablePorts;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _subscription;
  final StreamController<String> _controller = StreamController<String>.broadcast();
  final StringBuffer _buffer = StringBuffer();

  SerialPortWrapper(this.portName, {this.baudRate = 9600});

  /// Opens the serial port, returns true if successful, or false if not.
  bool open() {
    _port = SerialPort(portName);
    if (!_port!.openReadWrite()) {
      debugPrint("Failed to open port: ${SerialPort.lastError}");
      return false;
    }

    _reader = SerialPortReader(_port!);
    _subscription = _reader!.stream.listen(_onDataReceived);
    
    return true;
  }

  /// Handles incoming serial data
  void _onDataReceived(Uint8List data) {
    String received = String.fromCharCodes(data);
    _buffer.write(received);

    if (received.contains("\n")) {
      String fullLine = _buffer.toString().trim();
      _buffer.clear();
      _controller.add(fullLine); // Send the full response
    }
  }

  /// Sends a command and waits for a response (with timeout)
  Future<String> sendCommand(String command, {Duration timeout = const Duration(milliseconds: 5000)}) async {
    if (_port == null || !_port!.isOpen) {
      throw Exception("Serial port is not open");
    }

    _port!.write(Uint8List.fromList(command.codeUnits));

    try {
      return await _controller.stream.first.timeout(timeout);
    } catch (e) {  
      throw Exception("Timeout: No response received");

    }
  }

  /// Closes the serial port
  void close() {
    _subscription?.cancel();
    _port?.close();
    _port = null;
  }
}