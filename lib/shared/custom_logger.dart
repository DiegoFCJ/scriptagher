import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import 'logging/log_metadata.dart';

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
        rec.level.name,
        rec.loggerName,
        rec.time,
        rec.message,
      );
      await _writeToFile(logMessage, rec.level.name);
    });
  }

  static Future<Directory> _ensureDirectory(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Returns the root directory that contains every log created by the
  /// application.
  static Future<Directory> getLogRootDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final logRoot = Directory('${directory.path}/.scriptagher/logs');
    return _ensureDirectory(logRoot);
  }

  /// Returns (and optionally creates) the directory used to store the run logs
  /// for a particular bot.
  static Future<Directory> getRunLogsDirectory(String botIdentifier) async {
    final sanitized = LogMetadata.sanitizeIdentifier(botIdentifier);
    final logRoot = await getLogRootDirectory();
    final runDirectory = Directory('${logRoot.path}/runs/$sanitized');
    return _ensureDirectory(runDirectory);
  }

  /// Creates a run specific log file and writes the metadata header to it.
  Future<File> createRunLogFile(LogMetadata metadata) async {
    final runDirectory = await getRunLogsDirectory(metadata.botId);
    final logFile = File('${runDirectory.path}/${metadata.fileName}');
    await logFile.writeAsString(metadata.buildHeader(), mode: FileMode.write);
    return logFile;
  }

  // Scrive il log su file
  Future<void> _writeToFile(String logMessage, String level) async {
    final logRoot = await getLogRootDirectory();
    final logDirectory = await _ensureDirectory(Directory('${logRoot.path}/$todayDate'));

    // Determina il componente in base al livello o al tipo di operazione
    String component = _getComponent(level);
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
        return 'general';  // Può essere modificato se hai bisogno di più granularità per gli errori
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
  String _formatLogMessage(String level, String className, DateTime time, String message) {
    final timeFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
    final threadId = DateTime.now().millisecondsSinceEpoch;  // Simulazione del Thread ID

    return '[$timeFormatted] [$threadId] [$level] [$className] - $message';
  }

  // Metodo di debug
  void debug(String operationType, String description, {LogMetadata? metadata}) {
    _log(DEBUG_LEVEL, operationType, description, metadata: metadata);
  }

  // Metodo di info
  void info(String operationType, String description, {LogMetadata? metadata}) {
    _log(INFO_LEVEL, operationType, description, metadata: metadata);
  }

  // Metodo di warning
  void warn(String operationType, String description, {LogMetadata? metadata}) {
    _log(WARN_LEVEL, operationType, description, metadata: metadata);
  }

  // Metodo di errore
  void error(String operationType, String description, {LogMetadata? metadata}) {
    _log(ERROR_LEVEL, operationType, description, metadata: metadata);
  }

  // Metodo centrale per il logging
  void _log(String level, String operationType, String description,
      {LogMetadata? metadata}) {
    final formattedMessage = '[$operationType] - $description';
    final messageWithMetadata =
        metadata != null ? '$formattedMessage ${metadata.describe()}' : formattedMessage;
    Level logLevel;

    // Assegna il valore numerico in base al livello di log
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

    // Logga il messaggio con il livello corretto
    _logger.log(logLevel, messageWithMetadata);
  }
}
