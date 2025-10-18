import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../shared/constants/LOGS.dart';
import '../../shared/custom_logger.dart';
import '../../shared/services/telemetry_service.dart';
import '../server/db/bot_database.dart';
import '../server/server.dart';

Future<void> initializeBackend(
  CustomLogger logger,
  TelemetryService telemetryService,
) async {
  await _startDB(logger);
  await _startBackend(logger, telemetryService);
}

Future<void> _startDB(CustomLogger logger) async {
  final botDatabase = BotDatabase();

  try {
    logger.info(LOGS.serverStart, 'Attempting to initialize database...');
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      databaseFactory = databaseFactoryFfi;
    }
    await botDatabase.database;
    logger.info(LOGS.serverStart, 'Database initialized successfully');
  } catch (e) {
    logger.error(LOGS.serverError, 'Error initializing database: $e');
    if (!(Platform.isAndroid || Platform.isIOS)) {
      rethrow;
    }
  }
}

Future<void> _startBackend(
  CustomLogger logger,
  TelemetryService telemetryService,
) async {
  try {
    logger.info('Avvio del server...', 'Avvio del backend');
    await startServer();
    logger.info('Server avviato con successo', 'Avvio del backend');
  } catch (e) {
    logger.error(
      'Errore durante l\'avvio del server: $e',
      'Errore nel backend',
    );
    await telemetryService.recordExecutionFailure(
      reason: 'backend_start_failure',
      extra: {
        'error_type': e.runtimeType.toString(),
      },
    );
  }
}
