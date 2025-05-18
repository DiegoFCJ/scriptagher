import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bot.dart';

class BotGetService {
  static Future<Map<String, List<Bot>>> fetchBots() async {
    const url = 'http://localhost:8080/bots';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        // Converte e raggruppa i bot per linguaggio
        final Map<String, List<Bot>> groupedBots = {};
        for (var botJson in data) {
          final bot = Bot.fromJson(botJson);
          if (!groupedBots.containsKey(bot.language)) {
            groupedBots[bot.language] = [];
          }
          groupedBots[bot.language]?.add(bot);
        }

        return groupedBots;
      } else {
        throw Exception('Failed to load bots. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch bots: $e');
    }
  }
}
