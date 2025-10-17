import 'dart:convert';
import 'dart:io';
import 'package:scriptagher/shared/constants/permissions.dart';
import 'package:scriptagher/shared/custom_logger.dart';

class BotUtils {
  static final logger = CustomLogger();

  // Fetches bot details from a JSON file (bot.json)
  static Future<Map<String, dynamic>> fetchBotDetails(String botJsonPath,
      {String? expectedHash}) async {
    try {
      final botJsonFile = File(botJsonPath);
      if (!await botJsonFile.exists()) {
        throw FileSystemException('bot.json not found at: $botJsonPath');
      }

      String content = await botJsonFile.readAsString();
      final decoded = json.decode(content) as Map<String, dynamic>;
      return validateManifest(decoded, expectedHash: expectedHash);
    } catch (e) {
      logger.error('BotUtils', 'Error reading bot.json: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> validateManifest(Map<String, dynamic> manifest,
      {String? expectedHash}) {
    final requiredStringFields = {
      'botName',
      'description',
      'startCommand',
    };

    for (final field in requiredStringFields) {
      final value = manifest[field];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid or missing "$field" in manifest');
      }
    }

    final sha256 = manifest['sha256'];
    if (sha256 is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256.trim())) {
      throw FormatException('Invalid or missing SHA256 hash in manifest');
    }

    final normalizedHash = sha256.toLowerCase();
    if (expectedHash != null && normalizedHash != expectedHash.toLowerCase()) {
      throw FormatException(
          'Manifest hash mismatch. Expected $expectedHash but found $sha256');
    }

    final permissionsRaw = manifest['permissions'];
    if (permissionsRaw is! List) {
      throw FormatException('Invalid or missing permissions list in manifest');
    }

    final permissions = <String>[];
    for (final permission in permissionsRaw) {
      if (permission is! String) {
        throw FormatException('Permission entries must be strings');
      }

      final normalized = permission.trim();
      if (!BotPermissions.allowed.contains(normalized)) {
        throw FormatException('Unknown permission "$permission" in manifest');
      }
      if (!permissions.contains(normalized)) {
        permissions.add(normalized);
      }
    }

    return {
      'botName': manifest['botName'],
      'description': manifest['description'],
      'startCommand': manifest['startCommand'],
      'sha256': normalizedHash,
      'permissions': permissions,
    };
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