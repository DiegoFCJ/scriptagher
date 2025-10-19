import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bot.dart';

class BotDownloadService {
  BotDownloadService(
      {this.baseUrl = 'http://localhost:8080', http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<Bot> downloadBot(String language, String botName) async {
    final uri = Uri.parse(
        '$baseUrl/bots/${Uri.encodeComponent(language)}/${Uri.encodeComponent(botName)}');

    final response = await _httpClient.get(uri);
    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return Bot.fromJson(data);
    }

    String? backendMessage;
    try {
      final Map<String, dynamic> error =
          jsonDecode(response.body) as Map<String, dynamic>;
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) {
        backendMessage = message;
      }
    } catch (_) {
      // ignore decoding errors and throw generic one below
    }

    throw Exception(
        backendMessage ?? 'Download fallito (codice ${response.statusCode}).');
  }

  Future<void> deleteBot(String language, String botName) async {
    final uri = Uri.parse(
        '$baseUrl/bots/${Uri.encodeComponent(language)}/${Uri.encodeComponent(botName)}');

    final response = await _httpClient.delete(uri);

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    String? backendMessage;
    try {
      final Map<String, dynamic> error =
          jsonDecode(response.body) as Map<String, dynamic>;
      final message = error['message']?.toString();
      if (message != null && message.isNotEmpty) {
        backendMessage = message;
      }
    } catch (_) {
      // ignore decoding errors and throw generic one below
    }

    throw Exception(backendMessage ??
        'Eliminazione fallita (codice ${response.statusCode}).');
  }
}
