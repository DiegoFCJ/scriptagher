import 'dart:convert';
import 'dart:io';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/exceptions/bot_manifest_validation_exception.dart';

class BotUtils {
  static final logger = CustomLogger();

  // Fetches bot details from a JSON file (bot.json)
  static Future<Map<String, dynamic>> fetchBotDetails(String botJsonPath) async {
    try {
      final botJsonFile = File(botJsonPath);
      if (!await botJsonFile.exists()) {
        throw FileSystemException('bot.json not found at: $botJsonPath');
      }

      String content = await botJsonFile.readAsString();
      final decoded = json.decode(content);
      if (decoded is! Map<String, dynamic>) {
        throw BotManifestValidationException(
          invalidFields: {
            'manifest': 'expected a JSON object but received ${decoded.runtimeType}'
          },
        );
      }
      return validateBotManifest(Map<String, dynamic>.from(decoded));
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

  static const List<String> _possibleNameKeys = ['botName', 'name'];

  static Map<String, dynamic> validateBotManifest(Map<String, dynamic> manifest) {
    final missingFields = <String>[];
    final invalidFields = <String, String>{};

    String? resolvedNameKey;
    for (final key in _possibleNameKeys) {
      if (manifest.containsKey(key)) {
        resolvedNameKey = key;
        break;
      }
    }

    if (resolvedNameKey == null) {
      missingFields.add('name');
    }

    String? nameValue;
    if (resolvedNameKey != null) {
      final value = manifest[resolvedNameKey];
      if (value is String && value.trim().isNotEmpty) {
        nameValue = value.trim();
      } else {
        invalidFields['name'] = 'must be a non-empty string';
      }
    }

    final versionValue = manifest['version'];
    if (versionValue == null) {
      missingFields.add('version');
    } else if (versionValue is! String || versionValue.trim().isEmpty) {
      invalidFields['version'] = 'must be a non-empty string';
    }

    final permissionsValue = manifest['permissions'];
    List<String>? permissions;
    if (permissionsValue == null) {
      missingFields.add('permissions');
    } else if (permissionsValue is List) {
      final invalidEntries = permissionsValue.where((element) {
        if (element is! String) {
          return true;
        }
        return element.trim().isEmpty;
      });
      if (invalidEntries.isNotEmpty) {
        invalidFields['permissions'] =
            'must contain only non-empty string values';
      } else {
        permissions = permissionsValue.map((e) => (e as String).trim()).toList();
      }
    } else {
      invalidFields['permissions'] = 'must be a list of strings';
    }

    final hashValue = manifest['hash'];
    if (hashValue == null) {
      missingFields.add('hash');
    } else if (hashValue is! String || hashValue.trim().isEmpty) {
      invalidFields['hash'] = 'must be a non-empty string';
    }

    if (missingFields.isNotEmpty || invalidFields.isNotEmpty) {
      throw BotManifestValidationException(
        missingFields: missingFields,
        invalidFields: invalidFields,
      );
    }

    final validatedManifest = Map<String, dynamic>.from(manifest);
    if (nameValue != null) {
      validatedManifest['botName'] = nameValue;
      validatedManifest['name'] = nameValue;
    }
    if (permissions != null) {
      validatedManifest['permissions'] = permissions;
    }

    return validatedManifest;
  }
}
