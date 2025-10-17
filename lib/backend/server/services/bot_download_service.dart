import 'dart:io';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/utils/BotUtils.dart';
import 'package:scriptagher/shared/utils/ZipUtils.dart';
import '../db/bot_database.dart';
import '../models/bot.dart';
import 'package:scriptagher/shared/constants/APIS.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import '../exceptions/download_exceptions.dart';
import 'package:scriptagher/shared/services/telemetry_service.dart';

class BotDownloadService {
  final CustomLogger logger = CustomLogger();
  final BotDatabase botDatabase = BotDatabase();
  final TelemetryService telemetryService = TelemetryService();

  Future<Bot> downloadBot(String language, String botName) async {
    logger.info(LOGS.BOT_SERVICE, LOGS.downloadStart(language, botName));

    final botZipUrl =
        '${APIS.BASE_URL}/$language/$botName/$botName${APIS.ZIP_EXTENSION}';
    final botDir = Directory('${APIS.BOT_DIR_DATA_REMOTE}/$language/$botName');
    final botZip = File('${botDir.path}/$botName${APIS.ZIP_EXTENSION}');

    try {
      if (!await botZip.exists()) {
        if (!await botDir.exists()) {
          await botDir.create(recursive: true);
        }
        await downloadFile(
          botZipUrl,
          botZip,
          language: language,
          botName: botName,
        );
      }

      logger.info(LOGS.BOT_SERVICE, LOGS.extractStart(botZip.path));
      await ZipUtils.unzipFile(botZip.path, botDir.path);
      logger.info(LOGS.BOT_SERVICE, LOGS.extractComplete(botDir.path));

      final botJsonPath = '${botDir.path}/${APIS.BOT_FILE_CONFIG}';
      final botDetails = await BotUtils.fetchBotDetails(botJsonPath);

      final compat = BotCompat.fromManifest(botDetails['compat']);
      final startCommand =
          botDetails['startCommand'] ?? botDetails['entrypoint'] ?? '';
      final metadata = botDetails['metadata'];
      final tags = Bot.parseTags(
        botDetails['tags'] ??
            (metadata is Map<String, dynamic> ? metadata['tags'] : null),
      );
      final author = Bot.parseOptionalString(
        botDetails['author'] ??
            (metadata is Map<String, dynamic> ? metadata['author'] : null),
      );
      final version = Bot.parseOptionalString(
        botDetails['version'] ??
            (metadata is Map<String, dynamic> ? metadata['version'] : null),
      );
      final bot = Bot(
        botName: botDetails['botName'],
        description: botDetails['description'],
        startCommand: startCommand,
        sourcePath: botJsonPath,
        language: language,
        tags: tags,
        author: author,
        version: version,
        compat: compat,
      );
      await botDatabase.insertBot(bot);
      await botZip.delete();

      logger.info(LOGS.BOT_SERVICE, LOGS.downloadComplete(bot.botName));
      return bot;
    } on DownloadException catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Download exception: $e');
      await telemetryService.recordDownloadFailure(
        language: language,
        botName: botName,
        reason: 'download_exception',
        extra: {'error_type': e.runtimeType.toString()},
      );
      rethrow;
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Unexpected download error: $e');
      await telemetryService.recordDownloadFailure(
        language: language,
        botName: botName,
        reason: 'unexpected_error',
        extra: {'error_type': e.runtimeType.toString()},
      );
      rethrow;
    }
  }

  Future<void> downloadFile(
    String fileUrl,
    File destination, {
    String? language,
    String? botName,
  }) async {
    try {
      final response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode == 200) {
        await destination.writeAsBytes(response.bodyBytes);
      } else {
        final errorMessage = LOGS.errorDownload(fileUrl);
        logger.error(LOGS.BOT_SERVICE, errorMessage);
        await telemetryService.recordDownloadFailure(
          language: language,
          botName: botName,
          reason: 'http_${response.statusCode}',
          extra: {'status_code': response.statusCode},
        );
        throw DownloadException(
          'Failed to download file. Response code: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is DownloadException) {
        rethrow;
      }
      logger.error(LOGS.BOT_SERVICE, 'Download error: $e');
      await telemetryService.recordDownloadFailure(
        language: language,
        botName: botName,
        reason: 'network_error',
        extra: {'error_type': e.runtimeType.toString()},
      );
      throw DownloadException('Failed to download file: $e');
    }
  }
}
