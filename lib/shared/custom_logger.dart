import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class CustomLogger {
  final Logger _logger = Logger('CustomLogger'); // Non statico

  // Formato data
  static final DateFormat dateFormatter = DateFormat('yyyy-MM-dd');
  static final String todayDate = dateFormatter.format(DateTime.now());

  static const String DEBUG_LEVEL = 'DEBUG';
  static const String INFO_LEVEL = 'INFO';
  static const String WARN_LEVEL = 'WARN';
  static const String ERROR_LEVEL = 'ERROR';

  // Metodo per inizializzare il logger
  CustomLogger() {
    _logger.onRecord.listen((LogRecord rec) async {
      final logMessage = _formatLogMessage(
          rec.level.name, rec.loggerName, rec.time, rec.message);
      await _writeToFile(logMessage, rec.level.name);
    });
  }

  // Scrive il log su file
  Future<void> _writeToFile(String logMessage, String level) async {
    final directory = await getApplicationDocumentsDirectory();
    final logDirectory = Directory('${directory.path}/.scriptagher/logs/$todayDate');

    // Crea la cartella se non esiste
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }

    // Determina il componente in base al livello o al tipo di operazione
    final component = _getComponent(level);
    final logFile = File('${logDirectory.path}/$component.log');

    // Controlla la dimensione del file e ruota se necessario
    final fileSize = await logFile.exists() ? await logFile.length() : 0;
    if (fileSize > 10 * 1024 * 1024) {
      await _rotateLogFile(logFile);
    }

    // Scrive il messaggio nel file
    await logFile.writeAsString('$logMessage\n', mode: FileMode.append);
  }

  // Determina il componente in base al livello (può essere personalizzato)
  String _getComponent(String level) {
    switch (level) {
      case DEBUG_LEVEL:
        return 'backend';
      case INFO_LEVEL:
        return 'frontend';
      case WARN_LEVEL:
        return 'data';
      case ERROR_LEVEL:
        return 'general';
      default:
        return 'general';
    }
  }

  // Ruota i log se il file supera una certa dimensione
  Future<void> _rotateLogFile(File logFile) async {
    final now = DateTime.now();
    final archiveName = '${logFile.path}_${now.toIso8601String()}.log';

    // Rinomina il file esistente per archiviarlo
    await logFile.rename(archiveName);
    await logFile.create();
  }

  // Formatta il messaggio di log
  String _formatLogMessage(
      String level, String className, DateTime time, String message) {
    final timeFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
    final threadId = DateTime.now().millisecondsSinceEpoch;

    return '[$timeFormatted] [$threadId] [$level] [$className] - $message';
  }

  void debug(String operationType, String description,
      {Map<String, dynamic>? metadata}) {
    _log(DEBUG_LEVEL, operationType, description, metadata: metadata);
  }

  void info(String operationType, String description,
      {Map<String, dynamic>? metadata}) {
    _log(INFO_LEVEL, operationType, description, metadata: metadata);
  }

  void warn(String operationType, String description,
      {Map<String, dynamic>? metadata}) {
    _log(WARN_LEVEL, operationType, description, metadata: metadata);
  }

  void error(String operationType, String description,
      {Map<String, dynamic>? metadata}) {
    _log(ERROR_LEVEL, operationType, description, metadata: metadata);
  }

  void _log(String level, String operationType, String description,
      {Map<String, dynamic>? metadata}) {
    final buffer = StringBuffer('[$operationType] - $description');
    if (metadata != null && metadata.isNotEmpty) {
      buffer.write(' | metadata: ${jsonEncode(metadata)}');
    }

    Level logLevel;

    switch (level) {
      case DEBUG_LEVEL:
        logLevel = Level.FINEST; // DEBUG
        break;
      case INFO_LEVEL:
        logLevel = Level.INFO; // INFO
        break;
      case WARN_LEVEL:
        logLevel = Level.WARNING; // WARNING
        break;
      case ERROR_LEVEL:
        logLevel = Level.SEVERE; // ERROR
        break;
      default:
        logLevel = Level.INFO; // Default is INFO
        break;
    }

    _logger.log(logLevel, buffer.toString());
  }
}
