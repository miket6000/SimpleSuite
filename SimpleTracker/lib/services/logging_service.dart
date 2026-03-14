// services/logging_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart'; 
import 'package:flutter/foundation.dart';

class LoggingService {
  File? _logFile;
  final List<String> _log = [];
  List<String> get log => _log;

  Future<void> init() async {
    final directory = await _getLogDirectory();
    final timestamp = _generateTimestamp();
    final file = File('${directory.path}/serial_log_$timestamp.txt');

    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    _logFile = file;
  }

  String _generateTimestamp() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    return formatter.format(now);
  }

  Future<Directory> _getLogDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<void> append(String line) async {
    try {
      if (_logFile == null) {
        await init();
      }

      _log.add(line);
      final sink = _logFile!.openWrite(mode: FileMode.append);
      sink.writeln(line);
      await sink.flush();
      await sink.close();
    } catch (e) {
      debugPrint('Logging error: $e');
    }
  }

  Future<void> clearLog() async {
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }

  String? get currentLogPath => _logFile?.path;
}
