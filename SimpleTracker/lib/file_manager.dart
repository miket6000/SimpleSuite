import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<String> getSafeFilePath(String filename) async {
  Directory dir;
  debugPrint('About to get a safe path...');

  if (Platform.isAndroid || Platform.isIOS) {
    dir = await getApplicationDocumentsDirectory();
    debugPrint('Using mobile app docs directory: ${dir.path}');
  } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    // Use user's home/documents directory on desktop
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    dir = Directory('$home/Documents'); // or just home directory
  } else {
    // fallback
    dir = await getTemporaryDirectory(); // Safe but non-persistent
  }

  // Make sure directory exists
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  return '${dir.path}/$filename';
}
