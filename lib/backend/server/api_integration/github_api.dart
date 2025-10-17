import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';

class GitHubApi {
  final CustomLogger logger = CustomLogger();

  // URL base delle API di GitHub
  static const String baseUrl =
      'https://raw.githubusercontent.com/diegofcj/scriptagher/gh-pages/bots/';
     //https://raw.githubusercontent.com/diegofcj/scriptagher/gh-pages/bots

  // Funzione per ottenere la lista di bot
  Future<Map<String, List<Map<String, dynamic>>>> fetchBotsList() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bots.json'));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid bots index format');
        }

        final Map<String, List<Map<String, dynamic>>> normalized = {};

        for (final entry in decoded.entries) {
          final language = entry.key;
          final bots = entry.value;
          if (bots is! List) {
            logger.warn('GitHubApi',
                'Skipping bots list for $language: expected an array.');
            continue;
          }

          final normalizedBots = bots.whereType<Map<String, dynamic>>().map(
            (botData) {
              final normalizedBot = Map<String, dynamic>.from(botData);
              normalizedBot['language'] = language;
              normalizedBot['version'] =
                  normalizedBot['version']?.toString() ?? '';
              final author = normalizedBot['author'];
              if (author != null && author is! String) {
                normalizedBot['author'] = author.toString();
              }
              final tagsValue = normalizedBot['tags'];
              if (tagsValue is List) {
                normalizedBot['tags'] = tagsValue
                    .whereType<String>()
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList();
              } else {
                normalizedBot['tags'] = const <String>[];
              }
              return normalizedBot;
            },
          ).toList();

          normalized[language] = normalizedBots;
        }

        return normalized;
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
        final manifest = BotUtils.parseManifestContent(response.body);

        if (!manifest.containsKey('language') ||
            (manifest['language'] is! String) ||
            (manifest['language'] as String).trim().isEmpty) {
          manifest['language'] = language;
        }

        final versionValue = manifest['version'];
        if (versionValue is! String) {
          manifest['version'] = versionValue?.toString() ?? '';
        } else {
          manifest['version'] = versionValue.trim();
        }

        final authorValue = manifest['author'];
        if (authorValue == null) {
          manifest.remove('author');
        } else if (authorValue is! String) {
          manifest['author'] = authorValue.toString();
        } else {
          final trimmed = authorValue.trim();
          if (trimmed.isEmpty) {
            manifest.remove('author');
          } else {
            manifest['author'] = trimmed;
          }
        }

        final tagsValue = manifest['tags'];
        if (tagsValue is List) {
          manifest['tags'] = tagsValue
              .whereType<String>()
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList();
        } else {
          manifest['tags'] = const <String>[];
        }

        return manifest;
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
}
