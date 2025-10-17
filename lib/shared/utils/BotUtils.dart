import 'dart:convert';
import 'dart:io';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/models/bot_manifest.dart';

class BotUtils {
  static final logger = CustomLogger();

  // Fetches bot details from a JSON file (bot.json)
  static Future<BotManifest> fetchBotDetails(String botJsonPath) async {
    try {
      final botJsonFile = File(botJsonPath);
      if (!await botJsonFile.exists()) {
        throw FileSystemException('bot.json not found at: $botJsonPath');
      }

      String content = await botJsonFile.readAsString();
      final decoded = json.decode(content);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Bot.json deve contenere un oggetto JSON valido.');
      }

      return BotManifest.fromJson(decoded);
    } catch (e) {
      logger.error('BotUtils', 'Error reading bot.json: $e');
      rethrow;
    }
  }

  // Checks if a bot is available locally by looking for required files
  static Future<bool> isBotAvailableLocally(String language, String botName) async {
    String botPath = '.scriptagher/localbots/$language/$botName';
    Directory botDir = Directory(botPath);
    if (await botDir.exists()) {
      File botJson = File('${botDir.path}/bot.json');
      return await botJson.exists();
    }
    return false;
  }
}