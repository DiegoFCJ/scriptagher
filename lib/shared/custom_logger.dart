import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart';

import 'custom_logger_io.dart'
    if (dart.library.html) 'custom_logger_web.dart';

class CustomLogger {
  final Logger _logger = Logger('CustomLogger'); // Non statico
  final LogWriter _logWriter = LogWriter(todayDate);

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
    if (kIsWeb) {
      return;
    }

    final component = _getComponent(level);
    await _logWriter.write(logMessage, component);
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
