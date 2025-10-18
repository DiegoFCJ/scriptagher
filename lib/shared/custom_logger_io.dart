import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LogWriter {
  LogWriter(this.todayDate);

  final String todayDate;

  Future<void> write(String logMessage, String component) async {
    final directory = await getApplicationDocumentsDirectory();
    final logDirectory =
        Directory('${directory.path}/.scriptagher/logs/$todayDate');

    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }

    final logFile = File('${logDirectory.path}/$component.log');
    final fileSize = await logFile.exists() ? await logFile.length() : 0;
    if (fileSize > 10 * 1024 * 1024) {
      await _rotateLogFile(logFile);
    }

    await logFile.writeAsString('$logMessage\n', mode: FileMode.append);
  }

  Future<void> _rotateLogFile(File logFile) async {
    final now = DateTime.now();
    final archiveName = '${logFile.path}_${now.toIso8601String()}.log';

    await logFile.rename(archiveName);
    await logFile.create();
  }
}
