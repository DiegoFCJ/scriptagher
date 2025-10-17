import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bot.dart';

class BotFilters {
  final String query;
  final String? language;
  final String? tag;
  final String? author;
  final String? version;

  const BotFilters({
    this.query = '',
    this.language,
    this.tag,
    this.author,
    this.version,
  });

  bool get hasFilters {
    return query.isNotEmpty ||
        language != null ||
        tag != null ||
        author != null ||
        version != null;
  }

  BotFilters copyWith({
    String? query,
    String? language,
    String? tag,
    String? author,
    String? version,
  }) {
    return BotFilters(
      query: query ?? this.query,
      language: language ?? this.language,
      tag: tag ?? this.tag,
      author: author ?? this.author,
      version: version ?? this.version,
    );
  }
}

class BotGetService {
  final String baseUrl;

  BotGetService({this.baseUrl = 'http://localhost:8080'});

  Future<Map<String, List<Bot>>> fetchBots({BotFilters filters = const BotFilters()}) async {
    final url = Uri.parse('$baseUrl/bots');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final Map<String, List<Bot>> groupedBots = {};

        for (var botJson in data) {
          final bot = Bot.fromJson(botJson);
          groupedBots.putIfAbsent(bot.language, () => []).add(bot);
        }

        return filters.hasFilters
            ? filterGroupedBots(groupedBots, filters)
            : groupedBots;
      } else {
        throw Exception(
            'Failed to load bots. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch bots: $e');
    }
  }

  Future<List<Bot>> fetchLocalBotsFlat({BotFilters filters = const BotFilters()}) async {
    final grouped = await fetchLocalBots(filters: filters);
    return grouped.values.expand((bots) => bots).toList();
  }

  Future<Map<String, List<Bot>>> fetchLocalBots({BotFilters filters = const BotFilters()}) async {
    final url = Uri.parse('$baseUrl/localbots');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final Map<String, List<Bot>> groupedBots = {};

        for (var botJson in data) {
          final bot = Bot.fromJson(botJson);
          groupedBots.putIfAbsent(bot.language, () => []).add(bot);
        }

        return filters.hasFilters
            ? filterGroupedBots(groupedBots, filters)
            : groupedBots;
      } else {
        throw Exception(
            'Failed to load local bots. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch local bots: $e');
    }
  }

  Map<String, List<Bot>> filterGroupedBots(
      Map<String, List<Bot>> groupedBots, BotFilters filters) {
    final Map<String, List<Bot>> filtered = {};

    groupedBots.forEach((language, bots) {
      final filteredBots = bots.where((bot) => _matchesFilters(bot, filters)).toList();
      if (filteredBots.isNotEmpty) {
        filtered[language] = filteredBots;
      }
    });

    return filtered;
  }

  List<Bot> filterBots(List<Bot> bots, BotFilters filters) {
    return bots.where((bot) => _matchesFilters(bot, filters)).toList();
  }

  bool _matchesFilters(Bot bot, BotFilters filters) {
    final query = filters.query.toLowerCase();

    final matchesQuery = query.isEmpty ||
        bot.botName.toLowerCase().contains(query) ||
        bot.description.toLowerCase().contains(query) ||
        bot.language.toLowerCase().contains(query) ||
        bot.author.toLowerCase().contains(query) ||
        bot.version.toLowerCase().contains(query) ||
        bot.tags.any((tag) => tag.toLowerCase().contains(query));

    final matchesLanguage = filters.language == null ||
        bot.language.toLowerCase() == filters.language!.toLowerCase();
    final matchesTag = filters.tag == null ||
        bot.tags.any((tag) => tag.toLowerCase() == filters.tag!.toLowerCase());
    final matchesAuthor = filters.author == null ||
        bot.author.toLowerCase() == filters.author!.toLowerCase();
    final matchesVersion = filters.version == null ||
        bot.version.toLowerCase() == filters.version!.toLowerCase();

    return matchesQuery &&
        matchesLanguage &&
        matchesTag &&
        matchesAuthor &&
        matchesVersion;
  }
}
