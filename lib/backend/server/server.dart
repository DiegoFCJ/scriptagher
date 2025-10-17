import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/bot_controller.dart';
import 'services/bot_get_service.dart';
import 'services/bot_download_service.dart';
import 'services/execution_service.dart';
import 'services/execution_log_service.dart';
import 'db/bot_database.dart';
import 'routes.dart';
import 'package:scriptagher/backend/server/api_integration/github_api.dart';

Future<void> startServer() async {
  // Crea un'istanza del CustomLogger
  final CustomLogger logger = CustomLogger();

  final botDatabase = BotDatabase();
  final GitHubApi gitHubApi = GitHubApi();
  // Istanzia il BotService e BotController
  final botGetService = BotGetService(botDatabase, gitHubApi);
  final botDownloadService = BotDownloadService();
  final executionLogManager = ExecutionLogManager();
  final executionService = ExecutionService(botDatabase, executionLogManager);
  final botController = BotController(botDownloadService, botGetService);

  // Ottieni il router con le rotte definite
  final botRoutes = BotRoutes(botController);
  final router = Router();
  router.mount('/', botRoutes.router);
  router.get('/bots/<language>/<botName>/stream',
      (Request request, String language, String botName) {
    return executionService.streamExecution(request, language, botName);
  });
  router.get('/bots/<language>/<botName>/logs',
      (Request request, String language, String botName) {
    return executionService.listLogs(request, language, botName);
  });
  router.get('/bots/<language>/<botName>/logs/<runId>',
      (Request request, String language, String botName, String runId) {
    return executionService.downloadLog(request, language, botName, runId);
  });

  // Usa il middleware di logging per tracciare le richieste
  final handler = const Pipeline()
      .addMiddleware(logRequests()) // Middleware per il log delle richieste
      .addMiddleware(
          _logCustomRequests(logger)) // Usa il Custom Logger per le richieste
      .addHandler(router); // Usa il router per gestire le richieste

  try {
    // Avvio del server sulla porta 8080
    final server = await io.serve(handler, 'localhost', 8080);
    logger.info(LOGS.serverStart,
        'Server running at http://${server.address.host}:${server.port}');
  } catch (e) {
    // Log dell'errore se il server non riesce ad avviarsi
    logger.error(LOGS.serverError, 'Error starting server: $e');
  }
}

// Middleware personalizzato che usa il Custom Logger
Middleware _logCustomRequests(CustomLogger logger) {
  return (Handler innerHandler) {
    return (Request request) async {
      // Logga il metodo e l'URI della richiesta
      logger.info(LOGS.REQUEST_LOG,
          LOGS.requestReceived + '${request.method} ${request.requestedUri}');

      // Logga i dettagli della richiesta, come i parametri
      if (request.method == 'POST' || request.method == 'PUT') {
        // Logga il corpo della richiesta solo per POST o PUT
        final requestBody = await request.readAsString();
        logger.info(LOGS.REQUEST_LOG, 'Request Body: $requestBody');
      }

      return innerHandler(request);
    };
  };
}
