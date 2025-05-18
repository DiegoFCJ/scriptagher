import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/custom_logger.dart';

class GitHubApi {
  final CustomLogger logger = CustomLogger();

  // URL base delle API di GitHub
  static const String baseUrl =
      'https://raw.githubusercontent.com/diegofcj/scriptagher/bot-list/bots/';

  // Funzione per ottenere la lista di bot
  Future<Map<String, dynamic>> fetchBotsList() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bots.json'));

      if (response.statusCode == 200) {
        return json.decode(response.body); // Restituisce la mappa dei bot
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
        return json.decode(response.body); // Restituisce i dettagli del bot
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
