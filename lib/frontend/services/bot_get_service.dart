import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bot.dart';

class BotGetService {
  final String baseUrl;

  BotGetService({this.baseUrl = 'http://localhost:8080'});

  Future<Map<String, List<Bot>>> fetchBots({bool forceRefresh = false}) async {
    final String path = forceRefresh ? '$baseUrl/bots?refresh=true' : '$baseUrl/bots';
    final url = Uri.parse(path);

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

  Future<List<Bot>> fetchLocalBotsFlat() async {
    final grouped = await fetchLocalBots();
    return grouped.values.expand((bots) => bots).toList();
  }

  Future<Map<String, List<Bot>>> fetchLocalBots() async {
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

        return groupedBots;
      } else {
        throw Exception(
            'Failed to load local bots. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch local bots: $e');
    }
  }
}
