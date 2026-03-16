// services/logging_service.dart
import 'dart:collection';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

/// Log severity levels.
enum LogLevel { debug, info, serial, warning, error }

/// A single structured log entry.
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  String get formatted {
    final ts = DateFormat('HH:mm:ss.SSS').format(timestamp);
    final tag = level.name.toUpperCase().padRight(7);
    return '$ts [$tag] $message';
  }

  @override
  String toString() => formatted;
}

/// Structured logging service with severity levels, file persistence,
/// and a fixed-size in-memory ring buffer for the terminal UI.
class LoggingService {
  File? _logFile;

  /// Serialises file writes so concurrent _append calls don't interleave.
  Future<void> _writeChain = Future.value();

  /// Maximum number of entries kept in memory.
  static const int maxBufferSize = 2000;

  /// Fixed-capacity ring buffer of recent log entries.
  final Queue<LogEntry> _buffer = Queue<LogEntry>();

  /// Read-only view of the in-memory log for the UI.
  List<String> get log =>
      _buffer.map((e) => e.formatted).toList(growable: false);

  /// Callback notified whenever a new entry is appended (for provider to
  /// call notifyListeners).
  VoidCallback? onNewEntry;

  Future<void> init() async {
    final directory = await _getLogDirectory();
    final timestamp = _generateFileTimestamp();
    final file = File('${directory.path}/tracker_$timestamp.log');

    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    _logFile = file;
  }

  String _generateFileTimestamp() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return formatter.format(now);
  }

  Future<Directory> _getLogDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  // ---------------------------------------------------------------------------
  // Convenience methods by level
  // ---------------------------------------------------------------------------

  Future<void> debug(String message) => _append(LogLevel.debug, message);
  Future<void> info(String message) => _append(LogLevel.info, message);
  Future<void> serial(String message) => _append(LogLevel.serial, message);
  Future<void> warning(String message) => _append(LogLevel.warning, message);
  Future<void> error(String message) => _append(LogLevel.error, message);

  /// Log a state transition.
  Future<void> state(String from, String to) =>
      _append(LogLevel.info, 'STATE: $from → $to');

  // ---------------------------------------------------------------------------
  // Legacy compatibility
  // ---------------------------------------------------------------------------

  /// Append a raw string (legacy callers). Logged at [LogLevel.serial].
  Future<void> append(String line) => _append(LogLevel.serial, line);

  // ---------------------------------------------------------------------------
  // Core
  // ---------------------------------------------------------------------------

  Future<void> _append(LogLevel level, String message) async {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    );

    // Ring buffer: drop oldest when full
    if (_buffer.length >= maxBufferSize) {
      _buffer.removeFirst();
    }
    _buffer.add(entry);

    // Notify UI
    onNewEntry?.call();

    // Serialise file writes through a future chain so concurrent calls
    // cannot interleave their output on the same line.
    _writeChain = _writeChain.then((_) async {
      try {
        if (_logFile == null) await init();
        final sink = _logFile!.openWrite(mode: FileMode.append);
        sink.writeln(entry.formatted);
        await sink.flush();
        await sink.close();
      } catch (e) {
        debugPrint('Logging error: $e');
      }
    });

    return _writeChain;
  }

  Future<void> clearLog() async {
    _buffer.clear();
    // Wait for any in-flight writes to finish before truncating
    await _writeChain;
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }

  String? get currentLogPath => _logFile?.path;
}
