import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bot.dart';

class BotGetService {
  final String baseUrl;

  BotGetService({this.baseUrl = 'http://localhost:8080'});

  Future<Map<String, List<Bot>>> fetchBots({bool forceRefresh = false}) =>
      fetchOnlineBots(forceRefresh: forceRefresh);

  Future<Map<String, List<Bot>>> fetchOnlineBots({bool forceRefresh = false}) async {
    final uri = forceRefresh
        ? Uri.parse('$baseUrl/bots').replace(queryParameters: {
            'forceRefresh': 'true',
          })
        : Uri.parse('$baseUrl/bots');
    return _fetchGrouped(uri);
  }

  Future<Map<String, List<Bot>>> refreshOnlineBots() async =>
      fetchOnlineBots(forceRefresh: true);

  Future<Map<String, List<Bot>>> fetchDownloadedBots() async {
    return _fetchGrouped(Uri.parse('$baseUrl/bots/downloaded'));
  }

  Future<Map<String, List<Bot>>> fetchLocalBots() async {
    return _fetchGrouped(Uri.parse('$baseUrl/localbots'));
  }

  Future<List<Bot>> fetchLocalBotsFlat() async {
    final grouped = await fetchLocalBots();
    return grouped.values.expand((bots) => bots).toList();
  }

  Future<List<Bot>> fetchDownloadedBotsFlat() async {
    final grouped = await fetchDownloadedBots();
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
}
