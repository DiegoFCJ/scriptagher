import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/constants/APIS.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/services/telemetry_service.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';
import 'package:scriptagher/shared/utils/ZipUtils.dart';

import '../db/bot_database.dart';
import '../exceptions/download_exceptions.dart';
import '../models/bot.dart';

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

      final zipBytes = await botZip.readAsBytes();
      final archiveHash = sha256.convert(zipBytes).toString();
      await _validateManifestFromArchive(
          zipBytes, archiveHash, language, botName);

      logger.info(LOGS.BOT_SERVICE, LOGS.extractStart(botZip.path));
      await ZipUtils.unzipFile(botZip.path, botDir.path);
      logger.info(LOGS.BOT_SERVICE, LOGS.extractComplete(botDir.path));

      final botJsonPath = '${botDir.path}/${APIS.BOT_FILE_CONFIG}';
      final botDetails = await BotUtils.fetchBotDetails(botJsonPath,
          expectedSha256: archiveHash);

      final compat = BotCompat.fromManifest(botDetails['compat']);
      final startCommandValue = botDetails['startCommand'];
      final entrypointValue = botDetails['entrypoint'];
      final startCommand = startCommandValue is String && startCommandValue.isNotEmpty
          ? startCommandValue
          : (entrypointValue is String ? entrypointValue : '');
      final permissions = (botDetails['permissions'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      final botNameValue = botDetails['botName']?.toString() ?? botName;
      final descriptionValue = botDetails['description']?.toString() ?? '';
      final authorValue = botDetails['author']?.toString() ?? 'Sconosciuto';
      final versionValue = botDetails['version']?.toString() ?? '0.0.0';
      final platforms = _derivePlatformCompatibility(compat);

      final bot = Bot(
        botName: botNameValue,
        description: descriptionValue,
        startCommand: startCommand,
        sourcePath: botJsonPath,
        language: language,
        compat: compat,
        permissions: permissions,
        author: authorValue,
        version: versionValue,
        platformCompatibility: platforms,
        archiveSha256: botDetails['archiveSha256']?.toString(),
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
          'message': e.toString(),
        },
      );
      if (await botZip.exists()) {
        await botZip.delete();
      }
      rethrow;
    } on FormatException catch (e) {
      final message = e.message.isNotEmpty
          ? e.message
          : 'Manifest validation failed with an unknown error.';
      logger.error(LOGS.BOT_SERVICE,
          'Manifest validation failed for $language/$botName: $message');
      await telemetryService.recordDownloadFailure(
        language: language,
        botName: botName,
        reason: 'manifest_invalid',
        extra: {
          'error_type': e.runtimeType.toString(),
          'message': message,
        },
      );
      if (await botZip.exists()) {
        await botZip.delete();
      }
      throw DownloadException('Manifest validation failed: $message');
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Unexpected download error: $e');
      await telemetryService.recordDownloadFailure(
        language: language,
        botName: botName,
        reason: 'unexpected_error',
        extra: {
          'error_type': e.runtimeType.toString(),
          'message': e.toString(),
        },
      );
      if (await botZip.exists()) {
        await botZip.delete();
      }
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

  Future<void> _validateManifestFromArchive(List<int> zipBytes,
      String archiveHash, String language, String botName) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
      final manifestEntry = archive.files.firstWhere(
        (file) =>
            file.isFile &&
            file.name.toLowerCase() == APIS.BOT_FILE_CONFIG.toLowerCase(),
        orElse: () => throw DownloadException(
            'Manifest ${APIS.BOT_FILE_CONFIG} not found inside archive.'),
      );

      final contentBytes = manifestEntry.content;
      if (contentBytes is! List<int>) {
        throw DownloadException('Invalid manifest content for $botName.');
      }

      final manifestContent = utf8.decode(contentBytes);
      BotUtils.parseManifestContent(manifestContent,
          expectedSha256: archiveHash);
    } on DownloadException {
      rethrow;
    } on FormatException catch (e) {
      logger.error(LOGS.BOT_SERVICE,
          'Manifest validation failed for $language/$botName: $e');
      throw DownloadException('Manifest validation failed: ${e.message}');
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE,
          'Failed to read manifest for $language/$botName: $e');
      throw DownloadException('Unable to validate manifest: $e');
    }
  }

  List<String> _derivePlatformCompatibility(BotCompat compat) {
    final platforms = <String>{};
    if (compat.desktopRuntimes.isNotEmpty) {
      platforms.add('desktop');
    }
    if (compat.browserSupported == true) {
      platforms.add('browser');
    }
    return platforms.toList(growable: false);
  }
}

