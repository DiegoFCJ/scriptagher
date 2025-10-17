import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bot.dart';

class BotDownloadService {
  BotDownloadService({this.baseUrl = 'http://localhost:8080'});

  final String baseUrl;

  Future<Bot> downloadBot(String language, String botName) async {
    final uri = Uri.parse(
        '$baseUrl/bots/${Uri.encodeComponent(language)}/${Uri.encodeComponent(botName)}');

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return Bot.fromJson(data);
    }

    try {
      final Map<String, dynamic> error =
          jsonDecode(response.body) as Map<String, dynamic>;
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
    } catch (_) {
      // ignore decoding errors and throw generic one below
    }

    throw Exception('Download fallito (codice ${response.statusCode}).');
  }
}
