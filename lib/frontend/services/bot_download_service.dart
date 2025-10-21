import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/config/api_base_url.dart';

import '../models/bot.dart';

class BotDownloadService {
  BotDownloadService({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? ApiBaseUrl.require(),
        _httpClient = httpClient ?? http.Client();

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

    final backendMessage = _extractErrorMessage(response);
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

    final backendMessage = _extractErrorMessage(response);
    throw Exception(backendMessage ??
        'Eliminazione fallita (codice ${response.statusCode}).');
  }

  String? _extractErrorMessage(http.Response response) {
    final body = response.body;
    if (body.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final candidates = [decoded['message'], decoded['error']];
        for (final candidate in candidates) {
          if (candidate is String) {
            final trimmed = candidate.trim();
            if (trimmed.isNotEmpty) {
              return trimmed;
            }
          }
        }
      } else if (decoded is String) {
        final trimmed = decoded.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    } catch (_) {
      // ignore decoding errors and fall back to the raw body below
    }

    final trimmedBody = body.trim();
    return trimmedBody.isNotEmpty ? trimmedBody : null;
  }
}
