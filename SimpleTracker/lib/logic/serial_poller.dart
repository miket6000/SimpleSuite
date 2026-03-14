import 'dart:async';
import 'package:async/async.dart';
import '../providers/serial_provider.dart';

class PollCommand {
  final String command;
  final Duration delay;

  const PollCommand({
    required this.command,
    required this.delay,
  });
}

class SerialPoller {
  final SerialProvider serial;

  List<PollCommand> _commands = [];
  int _currentIndex = 0;

  bool _isPolling = false;
  CancelableOperation<void>? _currentDelay;

  SerialPoller({required this.serial});

  void configure({
    required List<PollCommand> commands,
    bool autoStart = true,
  }) {
    stop();

    _commands = List.from(commands);
    _currentIndex = 0;

    if (autoStart) {
      start();
    }
  }

  void start() {
    if (_isPolling || _commands.isEmpty) return;

    _isPolling = true;
    _runLoop();
  }

  Future<void> _runLoop() async {
    while (_isPolling && _commands.isNotEmpty) {
      if (!serial.isConnected) {
        stop();
        return;
      }

      final current = _commands[_currentIndex];

      // Send command
      serial.sendQueuedCommand(current.command);

      // Create cancelable delay
      _currentDelay = CancelableOperation.fromFuture(
        Future.delayed(current.delay),
      );

      try {
        await _currentDelay!.value;
      } catch (_) {
        // Cancelled — exit immediately
        return;
      }

      if (!_isPolling) return;

      _currentIndex = (_currentIndex + 1) % _commands.length;
    }
  }

  void stop() {
    _isPolling = false;
    _currentDelay?.cancel();
    _currentDelay = null;
  }

  bool get isPolling => _isPolling;
}