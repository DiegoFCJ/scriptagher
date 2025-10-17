import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/custom_logger.dart';

class GitHubApi {
  final CustomLogger logger = CustomLogger();

  // URL base delle API di GitHub
  static const String baseUrl =
      'https://raw.githubusercontent.com/diegofcj/scriptagher/gh-pages/bots/';
     //https://raw.githubusercontent.com/diegofcj/scriptagher/gh-pages/bots

  // Funzione per ottenere la lista di bot
  Future<Map<String, dynamic>> fetchBotsList() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bots.json'));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is Map<String, dynamic>) {
          decoded.forEach((language, bots) {
            if (bots is List) {
              for (final bot in bots.whereType<Map>()) {
                final normalized = _normalizeBotEntry(language, bot);
                bot
                  ..clear()
                  ..addAll(normalized);
              }
            }
          });
          return decoded;
        }

        return {};
      } else {
        logger.error('GitHubApi',
            'Failed to fetch bots list. Status code: ${response.statusCode}');
        throw Exception('Failed to load bots list');
      }
    } catch (e) {
      logger.error('GitHubApi', 'Error fetching bots list: $e');
      rethrow;
    }
  }

  // Funzione per ottenere i dettagli di un singolo bot
  Future<Map<String, dynamic>> fetchBotDetails(
      String language, String botName) async {
    try {
      final botJsonUrl = '$baseUrl/$language/$botName/Bot.json';
      final response = await http.get(Uri.parse(botJsonUrl));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return _normalizeBotDetails(decoded);
        }
        return {};
      } else {
        logger.error('GitHubApi',
            'Failed to fetch Bot.json for $botName. Status code: ${response.statusCode}');
        throw Exception('Failed to load Bot.json for $botName');
      }
    } catch (e) {
      logger.error('GitHubApi', 'Error fetching Bot.json for $botName: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _normalizeBotEntry(
      String language, Map<dynamic, dynamic> bot) {
    final metadata =
        (bot['metadata'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final tags = _parseTags(bot['tags'] ?? metadata['tags']);

    final normalizedMetadata = {
      ...metadata,
      'tags': tags,
      'author': metadata['author']?.toString() ?? bot['author']?.toString() ?? '',
      'version':
          metadata['version']?.toString() ?? bot['version']?.toString() ?? '',
    };

    return {
      ...bot.map((key, value) => MapEntry(key.toString(), value)),
      'language': bot['language']?.toString() ?? language,
      'tags': tags,
      'author': normalizedMetadata['author'],
      'version': normalizedMetadata['version'],
      'metadata': normalizedMetadata,
    };
  }

  Map<String, dynamic> _normalizeBotDetails(Map<String, dynamic> botDetails) {
    final metadata =
        (botDetails['metadata'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final tags = _parseTags(botDetails['tags'] ?? metadata['tags']);

    final normalizedMetadata = {
      ...metadata,
      'tags': tags,
      'author': metadata['author']?.toString() ?? botDetails['author']?.toString() ?? '',
      'version': metadata['version']?.toString() ??
          botDetails['version']?.toString() ??
          '',
    };

    return {
      ...botDetails,
      'tags': tags,
      'author': normalizedMetadata['author'],
      'version': normalizedMetadata['version'],
      'metadata': normalizedMetadata,
    };
  }

  List<String> _parseTags(dynamic tags) {
    if (tags == null) return [];
    if (tags is List) {
      return tags.map((tag) => tag.toString()).toList();
    }
    if (tags is String && tags.isNotEmpty) {
      return tags
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }
    return [];
  }
}
