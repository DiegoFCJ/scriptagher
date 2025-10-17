import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'dart:io';
import 'package:mime/mime.dart';
import '../services/bot_get_service.dart';
import '../services/bot_download_service.dart';
import '../services/bot_upload_service.dart';
import '../services/execution_service.dart';
import '../models/bot.dart';
import '../exceptions/download_exceptions.dart';

class BotController {
  final CustomLogger logger = CustomLogger();
  final BotDownloadService botDownloadService;
  final BotGetService botGetService;
  final BotUploadService botUploadService;
  final ExecutionService executionService;

  BotController(
      this.botDownloadService, this.botGetService, this.botUploadService, this.executionService);

  // Endpoint per ottenere la lista dei bot disponibili remoti
  Future<Response> fetchAvailableBots(Request request) async {
    try {
      logger.info(LOGS.BOT_SERVICE, 'Fetching list of available bots...');
      final query = request.requestedUri.queryParameters;
      final forceRefresh =
          query['forceRefresh'] == 'true' || query['force_refresh'] == 'true';
      final List<Bot> availableBots = await botGetService
          .fetchAvailableBots(forceRefresh: forceRefresh);

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

  Future<Response> startBot(
      Request request, String language, String botName) {
    return executionService.startBot(request, language, botName);
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
    } on DownloadException catch (e) {
      logger.warn(LOGS.BOT_SERVICE, 'Download failed: ${e.message}');
      return Response(400,
          body: json.encode({
            'error': 'Download failed',
            'message': e.message,
          }),
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

  Future<Response> uploadBot(Request request) async {
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return Response(400,
            body: json.encode({
              'error': 'Invalid request',
              'message': 'Content-Type must be multipart/form-data.',
            }),
            headers: {'Content-Type': 'application/json'});
      }

      final boundary = _extractBoundary(contentType);
      if (boundary == null) {
        return Response(400,
            body: json.encode({
              'error': 'Invalid request',
              'message': 'Multipart boundary missing.',
            }),
            headers: {'Content-Type': 'application/json'});
      }

      final transformer = MimeMultipartTransformer(boundary);
      final parts = transformer.bind(request.read());

      File? uploadedFile;
      Directory? uploadTempDir;
      await for (final part in parts) {
        final disposition = part.headers['content-disposition'];
        if (disposition == null || !disposition.contains('filename=')) {
          continue;
        }

        final filenameMatch =
            RegExp(r'filename="?([^";]*)"?').firstMatch(disposition);
        final filename = filenameMatch?.group(1) ?? 'upload.zip';
        uploadTempDir ??=
            await Directory.systemTemp.createTemp('bot_upload_');
        final file = File('${uploadTempDir.path}/$filename');
        final sink = file.openWrite();
        await part.pipe(sink);
        await sink.close();
        uploadedFile = file;
        break;
      }

      if (uploadedFile == null) {
        if (uploadTempDir != null && await uploadTempDir.exists()) {
          await uploadTempDir.delete(recursive: true);
        }
        return Response(400,
            body: json.encode({
              'error': 'Invalid request',
              'message': 'No file part found in upload.',
            }),
            headers: {'Content-Type': 'application/json'});
      }

      try {
        final bot = await botUploadService.importBotArchive(uploadedFile);

        return Response.ok(
          json.encode(bot.toResponseMap()),
          headers: {'Content-Type': 'application/json'},
        );
      } finally {
        if (uploadTempDir != null && await uploadTempDir.exists()) {
          await uploadTempDir.delete(recursive: true);
        }
      }
    } on FormatException catch (e) {
      logger.warn(LOGS.BOT_SERVICE, 'Invalid bot archive: ${e.message}');
      return Response(400,
          body: json.encode({
            'error': 'Invalid bot archive',
            'message': e.message,
          }),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Error uploading bot: $e');
      return Response.internalServerError(
        body: json.encode({
          'error': 'Error uploading bot',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  String? _extractBoundary(String contentType) {
    final boundaryIndex = contentType.indexOf('boundary=');
    if (boundaryIndex == -1) {
      return null;
    }
    var boundary = contentType.substring(boundaryIndex + 9);
    if (boundary.endsWith(';')) {
      boundary = boundary.substring(0, boundary.length - 1);
    }
    return boundary.replaceAll('"', '');
  }
}
