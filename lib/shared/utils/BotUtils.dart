import 'dart:convert';
import 'dart:io';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/exceptions/bot_manifest_validation_exception.dart';

class BotUtils {
  static final logger = CustomLogger();

  static const Map<String, Type> _manifestSchema = {
    'name': String,
    'version': String,
    'permissions': List,
    'hash': String,
  };

  static final RegExp _hashRegExp = RegExp(r'^[a-fA-F0-9]{64}$');

  // Fetches bot details from a JSON file (bot.json)
  static Future<Map<String, dynamic>> fetchBotDetails(String botJsonPath) async {
    try {
      final botJsonFile = File(botJsonPath);
      if (!await botJsonFile.exists()) {
        throw FileSystemException('bot.json not found at: $botJsonPath');
      }

      String content = await botJsonFile.readAsString();
      final dynamic decoded = json.decode(content);
      if (decoded is! Map<String, dynamic>) {
        throw BotManifestValidationException(
            'bot.json must contain a JSON object at the root.');
      }

      final manifest = Map<String, dynamic>.from(decoded);
      validateBotManifest(manifest);
      return manifest;
    } on BotManifestValidationException catch (e) {
      logger.error('BotUtils', 'Invalid bot manifest: ${e.message}');
      rethrow;
    } catch (e) {
      logger.error('BotUtils', 'Error reading bot.json: $e');
      rethrow;
    }
  }

  static void validateBotManifest(Map<String, dynamic> manifest) {
    for (final entry in _manifestSchema.entries) {
      final key = entry.key;
      final expectedType = entry.value;
      if (!manifest.containsKey(key)) {
        throw BotManifestValidationException(
            "Missing required field '$key' in bot.json manifest.");
      }

      final value = manifest[key];
      if (expectedType == String && value is! String) {
        throw BotManifestValidationException(
            "Field '$key' must be a string in bot.json manifest.");
      }
      if (expectedType == List && value is! List) {
        throw BotManifestValidationException(
            "Field '$key' must be a list in bot.json manifest.");
      }
    }

    final name = manifest['name'];
    if (name is String && name.trim().isEmpty) {
      throw BotManifestValidationException(
          "Field 'name' cannot be empty in bot.json manifest.");
    }

    final version = manifest['version'];
    if (version is String && version.trim().isEmpty) {
      throw BotManifestValidationException(
          "Field 'version' cannot be empty in bot.json manifest.");
    }

    final permissions = manifest['permissions'];
    if (permissions is List) {
      if (permissions.isEmpty) {
        throw BotManifestValidationException(
            "Field 'permissions' must contain at least one entry in bot.json manifest.");
      }
      final hasInvalidPermission = permissions.any(
        (permission) => permission is! String || permission.trim().isEmpty,
      );
      if (hasInvalidPermission) {
        throw BotManifestValidationException(
            "Field 'permissions' must contain only non-empty strings in bot.json manifest.");
      }
    }

    final hash = manifest['hash'];
    if (hash is String) {
      if (hash.trim().isEmpty) {
        throw BotManifestValidationException(
            "Field 'hash' cannot be empty in bot.json manifest.");
      }
      if (!_hashRegExp.hasMatch(hash)) {
        throw BotManifestValidationException(
            "Field 'hash' must be a 64-character hexadecimal string in bot.json manifest.");
      }
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
