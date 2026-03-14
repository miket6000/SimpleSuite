import 'dart:async';

class SerialCommandQueue {
  final Duration timeout;
  final Future<void> Function(String command) sendCommand;
  final List<_QueuedCommand> _queue = [];
  bool _isSending = false;

  String? currentCommand; // 👈 Track currently-sent command

  SerialCommandQueue({
    required this.sendCommand,
    this.timeout = const Duration(seconds: 5),
  });

  Future<String> enqueue(String command, {bool expectResponse = true}) {
    final completer = Completer<String>();
    final queued = _QueuedCommand(command, completer, expectResponse: expectResponse);
    _queue.add(queued);
    _processQueue();
    return completer.future;
  }

  String? handleIncomingResponse(String response) {
    if (_queue.isEmpty) return null;

    final current = _queue.first;
    // cancel timeout for this command
    current.timer?.cancel();

    final completedCommand = current.command; // capture before mutating

    if (!current.completer.isCompleted) {
      current.completer.complete(response);
    }

    _queue.removeAt(0);
    _isSending = false;
    _processQueue();

    return completedCommand;
  }

  // Fail and clear all pending queued commands (used when serial dies)
  void failAll([Object? reason]) {
    final err = reason ?? StateError('Serial connection lost');
    for (final q in _queue) {
      try {
        q.timer?.cancel();
      } catch (_) {}
      if (!q.completer.isCompleted) {
        q.completer.completeError(err);
      }
    }
    _queue.clear();
    _isSending = false;
    currentCommand = null;
  }

  void _processQueue() {
    if (_isSending || _queue.isEmpty) return;

    final current = _queue.first;
    currentCommand = current.command;
    _isSending = true;

    // Fire-and-forget path: command does not expect a response.
    if (!current.expectResponse) {
      sendCommand(current.command).then((_) {
        if (!current.completer.isCompleted) {
          current.completer.complete(''); // or some ack value
        }
      }).catchError((err) {
        if (!current.completer.isCompleted) {
          current.completer.completeError(err);
        }
      }).whenComplete(() {
        if (_queue.isNotEmpty && _queue.first == current) {
          _queue.removeAt(0);
        } else {
          _queue.remove(current);
        }
        _isSending = false;
        _processQueue();
      });
      return;
    }

    // existing expect-response path
    current.timer = Timer(timeout, () {
      if (!current.completer.isCompleted) {
        current.completer.completeError(TimeoutException('Timeout waiting for: ${current.command}'));
      }
      if (_queue.isNotEmpty && _queue.first == current) {
        _queue.removeAt(0);
      } else {
        _queue.remove(current);
      }
      _isSending = false;
      _processQueue();
    });

    sendCommand(current.command).catchError((err) {
      // on send error clear timer and complete
      current.timer?.cancel();
      if (!current.completer.isCompleted) {
        current.completer.completeError(err);
      }
      if (_queue.isNotEmpty && _queue.first == current) {
        _queue.removeAt(0);
      } else {
        _queue.remove(current);
      }
      _isSending = false;
      _processQueue();
    });
  }
}

class _QueuedCommand {
  final String command;
  final Completer<String> completer;
  final bool expectResponse;
  Timer? timer;

  _QueuedCommand(this.command, this.completer, {this.expectResponse = true});
}