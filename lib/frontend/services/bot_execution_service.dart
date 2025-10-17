import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bot.dart';

class BotExecutionService {
  final String baseUrl;

  BotExecutionService({this.baseUrl = 'http://localhost:8080'});

  Future<int> startBot(Bot bot) async {
    final url = Uri.parse('$baseUrl/bots/start');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(bot.toMap()),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final pid = data['processId'];
      if (pid is int) {
        return pid;
      } else if (pid is num) {
        return pid.toInt();
      }
      throw Exception('Invalid response format');
    } else {
      throw Exception('Failed to start bot: ${response.body}');
    }
  }
}
