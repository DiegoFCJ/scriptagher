import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import '../services/bot_get_service.dart';
import '../services/bot_download_service.dart';
import '../services/execution_service.dart';
import '../models/bot.dart';

class BotController {
  final CustomLogger logger = CustomLogger();
  final BotDownloadService botDownloadService;
  final BotGetService botGetService;
  final ExecutionService executionService;

  BotController(this.botDownloadService, this.botGetService, this.executionService);

  // Endpoint per ottenere la lista dei bot disponibili remoti
  Future<Response> fetchAvailableBots(Request request) async {
    try {
      logger.info(LOGS.BOT_SERVICE, 'Fetching list of available bots...');
      final List<Bot> availableBots = await botGetService
          .fetchAvailableBots(); // Restituisce una lista di bot con tutti i dettagli

      // Logga i dettagli della risposta
      logger.info(LOGS.BOT_SERVICE, 'Fetched ${availableBots.length} bots.');

      // Rispondi con la lista di bot in formato JSON
      return Response.ok(
          json.encode(availableBots
              .map((bot) => bot.toResponseMap())
              .toList()), // Converte ogni bot in una mappa JSON
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Error fetching bots: $e');
      return Response.internalServerError(
          body: json.encode({
            'error': 'Error fetching bots',
            'message': e.toString(),
          }),
          headers: {'Content-Type': 'application/json'});
    }
  }

  // Endpoint per scaricare un bot specifico
  Future<Response> downloadBot(
      Request request, String language, String botName) async {
    try {
      logger.info(LOGS.BOT_SERVICE, 'Downloading bot: $language/$botName');

      // Avvia il processo di download
      final bot = await botDownloadService.downloadBot(language, botName);

      // Logga i dettagli del bot scaricato
      logger.info(
          LOGS.BOT_SERVICE, 'Downloaded bot ${bot.botName} successfully.');

      // Rispondi con i dettagli del bot come JSON
      return Response.ok(json.encode(bot.toResponseMap()),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Error downloading bot: $e');
      return Response.internalServerError(
          body: json.encode({
            'error': 'Error downloading bot',
            'message': e.toString(),
          }),
          headers: {'Content-Type': 'application/json'});
    }
  }

  // Endpoint per ottenere la lista dei bot locali
  Future<Response> fetchLocalBots(Request request) async {
    try {
      logger.info(LOGS.BOT_SERVICE, 'Fetching list of local bots...');
      final List<Bot> localBots =
          await botGetService.fetchLocalBotsFromFilesystem();

      logger.info(LOGS.BOT_SERVICE, 'Fetched ${localBots.length} local bots.');
      return Response.ok(
        json.encode(localBots.map((bot) => bot.toResponseMap()).toList()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Error fetching local bots: $e');
      return Response.internalServerError(
        body: json.encode({
          'error': 'Error fetching local bots',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // Endpoint per ottenere la lista dei bot scaricati dal database
  Future<Response> fetchDownloadedBots(Request request) async {
    try {
      logger.info(LOGS.BOT_SERVICE, 'Fetching downloaded bots from DB...');
      final List<Bot> downloadedBots =
          await botGetService.fetchDownloadedBotsFromDb();

      logger.info(
          LOGS.BOT_SERVICE, 'Fetched ${downloadedBots.length} downloaded bots.');
      return Response.ok(
        json.encode(downloadedBots.map((bot) => bot.toResponseMap()).toList()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Error fetching downloaded bots: $e');
      return Response.internalServerError(
        body: json.encode({
          'error': 'Error fetching downloaded bots',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> stopBot(
      Request request, String language, String botName) async {
    final result = executionService.stopProcess(language, botName);
    return _buildExecutionResponse(language, botName, result, 'stop');
  }

  Future<Response> killBot(
      Request request, String language, String botName) async {
    final result = executionService.killProcess(language, botName);
    return _buildExecutionResponse(language, botName, result, 'kill');
  }

  Response _buildExecutionResponse(String language, String botName,
      ExecutionSignalResult? result, String action) {
    if (result == null) {
      final message =
          'Nessuna esecuzione registrata per $language/$botName.';
      logger.warn(
        LOGS.EXECUTION_SERVICE,
        message,
        metadata: {
          'language': language,
          'botName': botName,
          'action': action,
        },
      );
      return Response.notFound(
        json.encode({
          'error': message,
          'action': action,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final message = _executionMessage(result, language, botName);
    final payload = {
      'action': action,
      'message': message,
      'status': result.isRunning ? 'running' : 'stopped',
      ...result.toJson(),
    };

    if (result.signalDelivered) {
      logger.info(
        LOGS.EXECUTION_SERVICE,
        'Segnale ${result.signalName} inviato a $language/$botName.',
        metadata: {
          'language': language,
          'botName': botName,
          'action': action,
          'exitCode': result.exitCode,
        },
      );
    } else {
      logger.warn(
        LOGS.EXECUTION_SERVICE,
        'Segnale ${result.signalName} non consegnato a $language/$botName.',
        metadata: {
          'language': language,
          'botName': botName,
          'action': action,
          'exitCode': result.exitCode,
        },
      );
    }

    return Response.ok(
      json.encode(payload),
      headers: {'Content-Type': 'application/json'},
    );
  }

  String _executionMessage(
      ExecutionSignalResult result, String language, String botName) {
    if (!result.wasRunning && result.exitCode == null) {
      return 'Nessun processo in esecuzione per $language/$botName.';
    }

    if (result.wasRunning && !result.signalDelivered) {
      return 'Impossibile inviare ${result.signalName} a $language/$botName.';
    }

    if (!result.isRunning) {
      final exitCode = result.exitCode;
      if (exitCode != null) {
        return 'Processo terminato con exit code $exitCode.';
      }
      return 'Processo terminato.';
    }

    if (!result.signalDelivered) {
      return 'Segnale ${result.signalName} non consegnato.';
    }

    return 'Segnale ${result.signalName} inviato.';
  }
}
