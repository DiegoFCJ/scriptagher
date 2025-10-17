import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../custom_logger.dart';

/// Represents a single log file on disk alongside some metadata used by the UI.
class RunLogEntry {
  RunLogEntry({required this.file, required this.lastModified});

  final File file;
  final DateTime lastModified;

  String get fileName => file.uri.pathSegments.isNotEmpty
      ? file.uri.pathSegments.last
      : file.path;
}

class LogStorage {
  /// Returns a list of run log entries for the provided bot identifier sorted by
  /// last modification date (newest first).
  static Future<List<RunLogEntry>> fetchRunLogs(String botIdentifier) async {
    final directory = await CustomLogger.getRunLogsDirectory(botIdentifier);

    if (!await directory.exists()) {
      return [];
    }

    final entries = <RunLogEntry>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.log')) {
        final modified = await entity.lastModified();
        entries.add(RunLogEntry(file: entity, lastModified: modified));
      }
    }

    entries.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return entries;
  }

  /// Reads the content of a specific log file.
  static Future<String> readLogContent(RunLogEntry entry) async {
    return entry.file.readAsString();
  }

  /// Copies the provided log file into the user's downloads directory (when
  /// available) and returns the new file instance.
  static Future<File> exportLogFile(RunLogEntry entry) async {
    Directory? downloads;
    try {
      downloads = await getDownloadsDirectory();
    } catch (_) {
      downloads = null;
    }
    final targetDirectory =
        downloads ?? await getApplicationDocumentsDirectory();
    final targetFile = File('${targetDirectory.path}/${entry.fileName}');
    return entry.file.copy(targetFile.path);
  }
}
