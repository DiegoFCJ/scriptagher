import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/config/api_base_url.dart';

import '../models/bot.dart';
import '../models/bot_filter.dart';
import 'bot_get_service_web.dart';

abstract class BotGetService {
  const BotGetService.protected();

  factory BotGetService({String? baseUrl, http.Client? httpClient}) {
    final resolved = baseUrl ?? ApiBaseUrl.resolve();
    if (resolved != null && resolved.isNotEmpty) {
      return _ApiBotGetService(
        baseUrl: resolved,
        httpClient: httpClient ?? http.Client(),
      );
    }

    if (kIsWeb) {
      return BotGetServiceWeb(httpClient: httpClient);
    }

    throw StateError(
      'Nessun endpoint API configurato. '
      'Passa --dart-define=API_BASE_URL=<url> per abilitare tutte le funzionalità.',
    );
  }

  factory BotGetService.unavailable() => const _UnavailableBotGetService();

  Future<Map<String, List<Bot>>> fetchBots({
    bool forceRefresh = false,
    BotFilter? filter,
  }) =>
      fetchOnlineBots(forceRefresh: forceRefresh, filter: filter);

  Future<Map<String, List<Bot>>> fetchOnlineBots({
    bool forceRefresh = false,
    BotFilter? filter,
  });

  Future<List<Bot>> fetchOnlineBotsFlat({
    bool forceRefresh = false,
    BotFilter? filter,
  });

  Future<Map<String, List<Bot>>> refreshOnlineBots() =>
      fetchOnlineBots(forceRefresh: true);

  Future<Map<String, List<Bot>>> fetchDownloadedBots({BotFilter? filter});

  Future<List<Bot>> fetchDownloadedBotsFlat({BotFilter? filter});

  Future<Map<String, List<Bot>>> fetchLocalBots({BotFilter? filter});

  Future<List<Bot>> fetchLocalBotsFlat({BotFilter? filter});

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

class _ApiBotGetService extends BotGetService {
  _ApiBotGetService({
    required this.baseUrl,
    required http.Client httpClient,
  })  : _httpClient = httpClient,
        super.protected();

  final String baseUrl;
  final http.Client _httpClient;

  @override
  Future<Map<String, List<Bot>>> fetchOnlineBots({
    bool forceRefresh = false,
    BotFilter? filter,
  }) async {
    final uri = forceRefresh
        ? Uri.parse('$baseUrl/bots').replace(queryParameters: {
            'forceRefresh': 'true',
          })
        : Uri.parse('$baseUrl/bots');
    final grouped = await _fetchGrouped(uri);
    return applyFilter(grouped, filter);
  }

  @override
  Future<List<Bot>> fetchOnlineBotsFlat({
    bool forceRefresh = false,
    BotFilter? filter,
  }) async {
    final grouped = await fetchOnlineBots(
      forceRefresh: forceRefresh,
      filter: filter,
    );
    return grouped.values.expand((bots) => bots).toList();
  }

  @override
  Future<Map<String, List<Bot>>> fetchDownloadedBots({
    BotFilter? filter,
  }) async {
    final grouped = await _fetchGrouped(Uri.parse('$baseUrl/bots/downloaded'));
    return applyFilter(grouped, filter);
  }

  @override
  Future<List<Bot>> fetchDownloadedBotsFlat({BotFilter? filter}) async {
    final grouped = await fetchDownloadedBots(filter: filter);
    return grouped.values.expand((bots) => bots).toList();
  }

  @override
  Future<Map<String, List<Bot>>> fetchLocalBots({BotFilter? filter}) async {
    final grouped = await _fetchGrouped(Uri.parse('$baseUrl/localbots'));
    return applyFilter(grouped, filter);
  }

  @override
  Future<List<Bot>> fetchLocalBotsFlat({BotFilter? filter}) async {
    final grouped = await fetchLocalBots(filter: filter);
    return grouped.values.expand((bots) => bots).toList();
  }

  Future<Map<String, List<Bot>>> _fetchGrouped(Uri url) async {
    try {
      final response = await _httpClient.get(url);

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

class _UnavailableBotGetService extends BotGetService {
  const _UnavailableBotGetService() : super.protected();

  @override
  Future<Map<String, List<Bot>>> fetchOnlineBots({
    bool forceRefresh = false,
    BotFilter? filter,
  }) async => const {};

  @override
  Future<List<Bot>> fetchOnlineBotsFlat({
    bool forceRefresh = false,
    BotFilter? filter,
  }) async => const [];

  @override
  Future<Map<String, List<Bot>>> fetchDownloadedBots({
    BotFilter? filter,
  }) async => const {};

  @override
  Future<List<Bot>> fetchDownloadedBotsFlat({
    BotFilter? filter,
  }) async => const [];

  @override
  Future<Map<String, List<Bot>>> fetchLocalBots({
    BotFilter? filter,
  }) async => const {};

  @override
  Future<List<Bot>> fetchLocalBotsFlat({BotFilter? filter}) async => const [];
}
