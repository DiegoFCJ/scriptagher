import 'dart:convert';

import 'package:http/http.dart' as http;

class BotExecutionService {
  final String baseUrl;

  BotExecutionService({this.baseUrl = 'http://localhost:8080'});

  Future<int?> stopBot(String language, String botName) async {
    final response = await _sendCommand(language, botName, 'stop');
    return response['exitCode'] as int?;
  }

  Future<int?> killBot(String language, String botName) async {
    final response = await _sendCommand(language, botName, 'kill');
    return response['exitCode'] as int?;
  }

  Future<Map<String, dynamic>> _sendCommand(
      String language, String botName, String action) async {
    final url = Uri.parse('$baseUrl/bots/$language/$botName/$action');
    final response = await http.post(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 404) {
      throw Exception('Process not found for $language/$botName');
    } else {
      throw Exception(
          'Failed to $action bot. Status code: ${response.statusCode}');
    }
  }
}
