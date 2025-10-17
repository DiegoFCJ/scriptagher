import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bot.dart';

class BotGetService {
  final String baseUrl;

  BotGetService({this.baseUrl = 'http://localhost:8080'});

  Future<Map<String, List<Bot>>> fetchBots({BotFilter? filter}) =>
      fetchOnlineBots(filter: filter);

  Future<Map<String, List<Bot>>> fetchOnlineBots({BotFilter? filter}) async {
    final grouped = await _fetchGrouped(Uri.parse('$baseUrl/bots'));
    return _applyFilters(grouped, filter);
  }

  Future<Map<String, List<Bot>>> fetchDownloadedBots({
    BotFilter? filter,
  }) async {
    final grouped = await _fetchGrouped(Uri.parse('$baseUrl/bots/downloaded'));
    return _applyFilters(grouped, filter);
  }

  Future<Map<String, List<Bot>>> fetchLocalBots({BotFilter? filter}) async {
    final grouped = await _fetchGrouped(Uri.parse('$baseUrl/localbots'));
    return _applyFilters(grouped, filter);
  }

  Future<List<Bot>> fetchLocalBotsFlat({BotFilter? filter}) async {
    final grouped = await fetchLocalBots(filter: filter);
    return grouped.values.expand((bots) => bots).toList();
  }

  Future<List<Bot>> fetchDownloadedBotsFlat({BotFilter? filter}) async {
    final grouped = await fetchDownloadedBots(filter: filter);
    return grouped.values.expand((bots) => bots).toList();
  }

  Future<Map<String, List<Bot>>> _fetchGrouped(Uri url) async {
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final Map<String, List<Bot>> groupedBots = {};

        for (var botJson in data) {
          final bot = Bot.fromJson(botJson);
          groupedBots.putIfAbsent(bot.language, () => []).add(bot);
        }

        return groupedBots;
      } else {
        throw Exception(
          'Failed to load bots. Status Code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Failed to fetch bots: $e');
    }
  }

  Map<String, List<Bot>> _applyFilters(
    Map<String, List<Bot>> groupedBots,
    BotFilter? filter,
  ) {
    if (filter == null || filter.isEmpty) {
      return groupedBots;
    }

    final BotFilter normalized = filter.normalized();
    final Map<String, List<Bot>> filtered = {};

    groupedBots.forEach((language, bots) {
      final matchesLanguageGroup = normalized.language == null ||
          normalized.language!.isEmpty ||
          language.toLowerCase() == normalized.language;
      if (!matchesLanguageGroup) {
        return;
      }

      final List<Bot> matchingBots = bots.where((bot) {
        if (normalized.language != null &&
            normalized.language!.isNotEmpty &&
            bot.language.toLowerCase() != normalized.language) {
          return false;
        }

        if (normalized.author != null &&
            bot.author?.toLowerCase() != normalized.author) {
          return false;
        }

        if (normalized.version != null &&
            bot.version?.toLowerCase() != normalized.version) {
          return false;
        }

        if (normalized.tags.isNotEmpty) {
          final botTags = bot.tags.map((tag) => tag.toLowerCase()).toSet();
          if (!botTags.containsAll(normalized.tags)) {
            return false;
          }
        }

        if (normalized.query != null && normalized.query!.isNotEmpty) {
          final query = normalized.query!;
          final haystack = <String?>[
            bot.botName,
            bot.description,
            bot.author,
            bot.version,
            bot.language,
          ];
          final tagString = bot.tags.join(' ').toLowerCase();
          final matchesText = haystack.whereType<String>().any(
                    (value) => value.toLowerCase().contains(query),
                  ) ||
              (tagString.isNotEmpty && tagString.contains(query));
          if (!matchesText) {
            return false;
          }
        }

        return true;
      }).toList();

      if (matchingBots.isNotEmpty) {
        filtered[language] = matchingBots;
      }
    });

    return filtered;
  }

  Map<String, List<Bot>> filterGroupedBots(
    Map<String, List<Bot>> groupedBots,
    BotFilter? filter,
  ) {
    return _applyFilters(groupedBots, filter);
  }
}

class BotFilter {
  final String? query;
  final String? language;
  final String? author;
  final String? version;
  final Set<String> tags;

  const BotFilter({
    this.query,
    this.language,
    this.author,
    this.version,
    Set<String>? tags,
  }) : tags = tags ?? const {};

  bool get isEmpty {
    return (query == null || query!.trim().isEmpty) &&
        (language == null || language!.trim().isEmpty) &&
        (author == null || author!.trim().isEmpty) &&
        (version == null || version!.trim().isEmpty) &&
        tags.isEmpty;
  }

  BotFilter copyWith({
    String? query,
    String? language,
    String? author,
    String? version,
    Set<String>? tags,
  }) {
    return BotFilter(
      query: query ?? this.query,
      language: language ?? this.language,
      author: author ?? this.author,
      version: version ?? this.version,
      tags: tags ?? this.tags,
    );
  }

  BotFilter normalized() {
    String? normalize(String? value) {
      if (value == null) return null;
      final trimmed = value.trim().toLowerCase();
      return trimmed.isEmpty ? null : trimmed;
    }

    return BotFilter(
      query: normalize(query),
      language: normalize(language),
      author: normalize(author),
      version: normalize(version),
      tags: tags
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty)
          .toSet(),
    );
  }
}
