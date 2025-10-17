import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bot.dart';
import '../models/bot_filter.dart';

class BotGetService {
  final String baseUrl;

  BotGetService({this.baseUrl = 'http://localhost:8080'});

  Future<Map<String, List<Bot>>> fetchBots(
          {bool forceRefresh = false, BotFilter? filter}) =>
      fetchOnlineBots(forceRefresh: forceRefresh, filter: filter);

  Future<Map<String, List<Bot>>> fetchOnlineBots(
      {bool forceRefresh = false, BotFilter? filter}) async {
    final uri = forceRefresh
        ? Uri.parse('$baseUrl/bots').replace(queryParameters: {
            'forceRefresh': 'true',
          })
        : Uri.parse('$baseUrl/bots');
    final grouped = await _fetchGrouped(uri);
    return applyFilter(grouped, filter);
  }

  Future<Map<String, List<Bot>>> refreshOnlineBots() async =>
      fetchOnlineBots(forceRefresh: true);

  Future<Map<String, List<Bot>>> fetchDownloadedBots({BotFilter? filter}) async {
    final grouped = await _fetchGrouped(Uri.parse('$baseUrl/bots/downloaded'));
    return applyFilter(grouped, filter);
  }

  Future<Map<String, List<Bot>>> fetchLocalBots({BotFilter? filter}) async {
    final grouped = await _fetchGrouped(Uri.parse('$baseUrl/localbots'));
    return applyFilter(grouped, filter);
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
            'Failed to load bots. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch bots: $e');
    }
  }

  Map<String, List<Bot>> applyFilter(
      Map<String, List<Bot>> groupedBots, BotFilter? filter) {
    if (filter == null || filter.isEmpty) {
      return groupedBots;
    }

    final Map<String, List<Bot>> filtered = {};
    groupedBots.forEach((language, bots) {
      final filteredBots = bots.where(filter.matches).toList();
      if (filteredBots.isNotEmpty) {
        filtered[language] = filteredBots;
      }
    });

    return filtered;
  }
}
