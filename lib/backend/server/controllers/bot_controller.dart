import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import '../services/bot_get_service.dart';
import '../services/bot_download_service.dart';
import '../models/bot.dart';
import 'package:scriptagher/shared/exceptions/bot_manifest_validation_exception.dart';

class BotController {
  final CustomLogger logger = CustomLogger();
  final BotDownloadService botDownloadService;
  final BotGetService botGetService;

  BotController(this.botDownloadService, this.botGetService);

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
              .map((bot) => bot.toMap())
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
      return Response.ok(json.encode(bot.toMap()),
          headers: {'Content-Type': 'application/json'});
    } on BotManifestValidationException catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Manifest validation failed: ${e.message}');
      return Response(
        400,
        body: json.encode({
          'error': 'Invalid bot manifest',
          'message': e.message,
        }),
        headers: {'Content-Type': 'application/json'},
      );
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
      final List<Bot> localBots = await botGetService.fetchLocalBotsFromDbAndFs();

      logger.info(LOGS.BOT_SERVICE, 'Fetched ${localBots.length} local bots.');
      return Response.ok(
        json.encode(localBots.map((bot) => bot.toMap()).toList()),
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

  Future<Response> importLocalBot(Request request) async {
    try {
      final body = await request.readAsString();
      final payload = json.decode(body);

      if (payload is! Map<String, dynamic>) {
        return Response(
          400,
          body: json.encode({
            'error': 'Invalid request body',
            'message': 'Expected a JSON object with import details',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final language = payload['language'];
      final botDirectory = payload['botDirectory'] ?? payload['path'];

      if (language is! String || language.trim().isEmpty) {
        return Response(
          400,
          body: json.encode({
            'error': 'Invalid language',
            'message': 'The language field must be a non-empty string',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (botDirectory is! String || botDirectory.trim().isEmpty) {
        return Response(
          400,
          body: json.encode({
            'error': 'Invalid bot directory',
            'message': 'Provide the botDirectory path containing the manifest',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final bot = await botDownloadService.importLocalBot(
        language.trim(),
        botDirectory.trim(),
      );

      return Response.ok(
        json.encode(bot.toMap()),
        headers: {'Content-Type': 'application/json'},
      );
    } on BotManifestValidationException catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Manifest validation failed: ${e.message}');
      return Response(
        400,
        body: json.encode({
          'error': 'Invalid bot manifest',
          'message': e.message,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on FormatException catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Invalid JSON body: $e');
      return Response(
        400,
        body: json.encode({
          'error': 'Invalid request body',
          'message': 'Unable to parse JSON payload',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on FileSystemException catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Filesystem error during import: $e');
      return Response(
        400,
        body: json.encode({
          'error': 'Local import error',
          'message': e.message ?? 'Required files were not found',
          'path': e.path,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Error importing local bot: $e');
      return Response.internalServerError(
        body: json.encode({
          'error': 'Error importing local bot',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
