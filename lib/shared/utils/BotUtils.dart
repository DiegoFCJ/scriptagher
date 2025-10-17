import 'dart:convert';
import 'dart:io';

import 'package:scriptagher/shared/custom_logger.dart';

class BotUtils {
  static final logger = CustomLogger();

  // Fetches bot details from a JSON file (bot.json)
  static Future<Map<String, dynamic>> fetchBotDetails(String botJsonPath,
      {String? expectedSha256}) async {
    try {
      final botJsonFile = File(botJsonPath);
      if (!await botJsonFile.exists()) {
        throw FileSystemException('bot.json not found at: $botJsonPath');
      }

      final content = await botJsonFile.readAsString();
      return parseManifestContent(content, expectedSha256: expectedSha256);
    } catch (e) {
      logger.error('BotUtils', 'Error reading bot.json: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> parseManifestContent(String content,
      {String? expectedSha256}) {
    final dynamic decoded = json.decode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Manifest must be a JSON object');
    }
    return _validateManifest(decoded, expectedSha256: expectedSha256);
  }

  static Map<String, dynamic> _validateManifest(Map<String, dynamic> manifest,
      {String? expectedSha256}) {
    final normalized = Map<String, dynamic>.from(manifest);

    final botName = _requireNonEmptyStringField(normalized,
        const ['botName', 'name'], 'Manifest must include a non-empty botName');
    normalized['botName'] = botName;

    final version = _requireNonEmptyStringField(normalized, const ['version'],
        'Manifest must include a non-empty version');
    normalized['version'] = version;

    final languageValue = normalized['language'];
    if (languageValue is String) {
      normalized['language'] = languageValue.trim();
    }

    final dynamic shaCandidate =
        normalized['archiveSha256'] ?? normalized['sha256'];
    if (shaCandidate is! String || shaCandidate.trim().isEmpty) {
      throw const FormatException(
          'Manifest must include a non-empty archiveSha256 field');
    }

    final archiveSha = shaCandidate.trim().toLowerCase();
    final shaRegex = RegExp(r'^[a-f0-9]{64}$');
    if (!shaRegex.hasMatch(archiveSha)) {
      throw const FormatException(
          'archiveSha256 must be a valid SHA-256 hexadecimal string');
    }

    if (expectedSha256 != null &&
        archiveSha != expectedSha256.toLowerCase()) {
      throw const FormatException(
          'archiveSha256 does not match the downloaded archive hash');
    }

    normalized['archiveSha256'] = archiveSha;

    final dynamic permissionsValue = normalized['permissions'];
    if (permissionsValue == null) {
      throw const FormatException('Manifest must include a permissions field');
    }
    if (permissionsValue is! List) {
      throw const FormatException('permissions must be an array of strings');
    }

    final permissions = <String>[];
    for (final entry in permissionsValue) {
      if (entry is! String || entry.trim().isEmpty) {
        throw const FormatException(
            'permissions must contain only non-empty strings');
      }
      permissions.add(entry.trim());
    }

    normalized['permissions'] = permissions;

    final authorValue = normalized['author'];
    if (authorValue is String) {
      final trimmed = authorValue.trim();
      if (trimmed.isEmpty) {
        normalized.remove('author');
      } else {
        normalized['author'] = trimmed;
      }
    } else if (authorValue != null) {
      final trimmed = authorValue.toString().trim();
      if (trimmed.isEmpty) {
        normalized.remove('author');
      } else {
        normalized['author'] = trimmed;
      }
    } else {
      normalized.remove('author');
    }

    final tagsValue = normalized['tags'];
    if (tagsValue is List) {
      final tags = tagsValue
          .whereType<String>()
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      normalized['tags'] = tags;
    } else {
      normalized['tags'] = const <String>[];
    }

    return normalized;
  }

  static String _requireNonEmptyStringField(Map<String, dynamic> manifest,
      List<String> candidateKeys, String errorMessage) {
    for (final key in candidateKeys) {
      final value = manifest[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    throw FormatException(errorMessage);
  }

  // Checks if a bot is available locally by looking for required files
  static Future<bool> isBotAvailableLocally(
      String language, String botName) async {
    String botPath = '.scriptagher/localbots/$language/$botName';
    Directory botDir = Directory(botPath);
    if (await botDir.exists()) {
      File botJson = File('${botDir.path}/bot.json');
      return await botJson.exists();
    }
    return false;
  }
}
