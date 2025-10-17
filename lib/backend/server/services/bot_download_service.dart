import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/custom_logger.dart';
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

      final manifestData = await _loadManifest(botZip);
      final expectedHash = manifestData.manifest['sha256'] as String;
      final actualHash = sha256.convert(manifestData.bytes).toString();

      if (actualHash.toLowerCase() != expectedHash.toLowerCase()) {
        await botZip.delete().catchError((_) {});
        throw DownloadException(
            'Downloaded archive hash mismatch for $language/$botName');
      }

      logger.info(LOGS.BOT_SERVICE, LOGS.extractStart(botZip.path));
      await ZipUtils.unzipFile(botZip.path, botDir.path);
      logger.info(LOGS.BOT_SERVICE, LOGS.extractComplete(botDir.path));

      final botJsonPath = '${botDir.path}/${APIS.BOT_FILE_CONFIG}';
      final botDetails = await BotUtils.fetchBotDetails(
        botJsonPath,
        expectedHash: expectedHash,
      );

      final bot = Bot(
        botName: botDetails['botName'],
        description: botDetails['description'],
        startCommand: botDetails['startCommand'],
        sourcePath: botJsonPath,
        language: language,
        permissions:
            List<String>.from(botDetails['permissions'] as List<dynamic>),
        archiveHash: botDetails['sha256'] as String,
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
        extra: {
          'error_type': e.runtimeType.toString(),
        },
      );
      rethrow;
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Unexpected download error: $e');
      await telemetryService.recordDownloadFailure(
        language: language,
        botName: botName,
        reason: 'unexpected_error',
        extra: {
          'error_type': e.runtimeType.toString(),
        },
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
          extra: {
            'status_code': response.statusCode,
          },
        );
        throw DownloadException(
            'Failed to download file. Response code: ${response.statusCode}');
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
        extra: {
          'error_type': e.runtimeType.toString(),
        },
      );
      throw DownloadException('Failed to download file: $e');
    }
  }

  Future<({Map<String, dynamic> manifest, List<int> bytes})> _loadManifest(
      File botZip) async {
    try {
      final bytes = await botZip.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifestFile = archive.files.firstWhere(
        (file) =>
            file.isFile &&
            file.name.toLowerCase().endsWith(
                APIS.BOT_FILE_CONFIG.toLowerCase()),
        orElse: () => throw DownloadException(
            'Manifest ${APIS.BOT_FILE_CONFIG} not found in archive ${botZip.path}'),
      );

      final content = manifestFile.content;
      if (content is! List<int>) {
        throw DownloadException('Invalid manifest content in archive');
      }

      final manifestJson =
          json.decode(utf8.decode(content)) as Map<String, dynamic>;
      final manifest = BotUtils.validateManifest(manifestJson);
      return (manifest: manifest, bytes: bytes);
    } catch (e) {
      if (e is DownloadException) {
        rethrow;
      }
      throw DownloadException('Failed to load manifest: $e');
    }
  }
}