import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/utils/BotUtils.dart';
import 'package:scriptagher/shared/utils/ZipUtils.dart';
import '../db/bot_database.dart';
import '../models/bot.dart';
import 'package:scriptagher/shared/constants/APIS.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import '../exceptions/download_exceptions.dart';
import 'package:scriptagher/shared/models/bot_manifest.dart';

class BotDownloadService {
  final CustomLogger logger = CustomLogger();
  final BotDatabase botDatabase = BotDatabase();

  Future<Bot> downloadBot(String language, String botName) async {
    logger.info(LOGS.BOT_SERVICE, LOGS.downloadStart(language, botName));

    final botZipUrl = '${APIS.BASE_URL}/$language/$botName/$botName${APIS.ZIP_EXTENSION}';
    final botDir = Directory('${APIS.BOT_DIR_DATA_REMOTE}/$language/$botName');
    final botZip = File('${botDir.path}/$botName${APIS.ZIP_EXTENSION}');

    if (!await botZip.exists()) {
      if (!await botDir.exists()) {
        await botDir.create(recursive: true);
      }
      await downloadFile(botZipUrl, botZip);
    }

    final downloadedHash = await _computeSha256(botZip);

    logger.info(LOGS.BOT_SERVICE, LOGS.extractStart(botZip.path));
    await ZipUtils.unzipFile(botZip.path, botDir.path);
    logger.info(LOGS.BOT_SERVICE, LOGS.extractComplete(botDir.path));

    final botJsonPath = '${botDir.path}/${APIS.BOT_FILE_CONFIG}';
    BotManifest manifest;
    try {
      manifest = await BotUtils.fetchBotDetails(botJsonPath);
    } on FormatException catch (e) {
      await _cleanupOnFailure(botZip, botDir);
      final message =
          'Manifest non valido per $botName: ${e.message ?? e.toString()}';
      logger.error(LOGS.BOT_SERVICE, message);
      throw DownloadException(message);
    }

    if (manifest.hash != downloadedHash) {
      await _cleanupOnFailure(botZip, botDir);
      final message =
          'Hash del file scaricato non corrispondente al manifest per $botName.';
      logger.error(LOGS.BOT_SERVICE, message);
      throw DownloadException(message);
    }

    final bot = Bot(
      botName: manifest.botName,
      description: manifest.description,
      startCommand: manifest.startCommand,
      sourcePath: botJsonPath,
      language: language,
      hash: manifest.hash,
      permissions: manifest.permissions,
    );
    await botDatabase.insertBot(bot);
    await botZip.delete();

    logger.info(LOGS.BOT_SERVICE, LOGS.downloadComplete(bot.botName));
    return bot;
  }

  Future<void> downloadFile(String fileUrl, File destination) async {
    final response = await http.get(Uri.parse(fileUrl));

    if (response.statusCode == 200) {
      await destination.writeAsBytes(response.bodyBytes);
    } else {
      final errorMessage = LOGS.errorDownload(fileUrl);
      logger.error(LOGS.BOT_SERVICE, errorMessage);
      throw DownloadException('Failed to download file. Response code: ${response.statusCode}');
    }
  }

  Future<String> _computeSha256(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _cleanupOnFailure(File botZip, Directory botDir) async {
    if (await botZip.exists()) {
      await botZip.delete();
    }

    if (await botDir.exists()) {
      await botDir.delete(recursive: true);
    }
  }
}