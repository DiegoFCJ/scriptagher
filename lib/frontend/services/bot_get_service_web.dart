import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:scriptagher/shared/constants/APIS.dart';

import '../models/bot.dart';
import '../models/bot_filter.dart';
import 'bot_get_service.dart';

class BotGetServiceWeb extends BotGetService {
  BotGetServiceWeb({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        super.protected();

  final http.Client _httpClient;
  Map<String, List<Bot>>? _cachedBots;

  static final Uri _botlistUri =
      Uri.parse('${APIS.BASE_URL_GH_PAGES}botlist.json');

  @override
  Future<Map<String, List<Bot>>> fetchOnlineBots({
    bool forceRefresh = false,
    BotFilter? filter,
  }) async {
    final grouped = await _loadBotlist(forceRefresh: forceRefresh);
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
  }) async => const {};

  @override
  Future<List<Bot>> fetchDownloadedBotsFlat({BotFilter? filter}) async =>
      const [];

  @override
  Future<Map<String, List<Bot>>> fetchLocalBots({BotFilter? filter}) async =>
      const {};

  @override
  Future<List<Bot>> fetchLocalBotsFlat({BotFilter? filter}) async => const [];

  Future<Map<String, List<Bot>>> _loadBotlist({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBots != null) {
      return _cachedBots!;
    }

    final response = await _httpClient.get(_botlistUri);
    if (response.statusCode != 200) {
      throw Exception(
        'Impossibile caricare botlist.json (status ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final grouped = _parseBotlist(decoded);
    _cachedBots = grouped;
    return grouped;
  }

  Map<String, List<Bot>> _parseBotlist(dynamic payload) {
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Formato botlist non valido');
    }

    final botsData = payload['bots'];
    if (botsData is! List) {
      return const {};
    }

    final Map<String, List<Bot>> grouped = {};
    for (final entry in botsData) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final manifest = entry['manifest'];
      final manifestMap = manifest is Map<String, dynamic>
          ? Map<String, dynamic>.from(manifest)
          : <String, dynamic>{};

      final bot = _botFromManifest(entry, manifestMap);
      grouped.putIfAbsent(bot.language, () => <Bot>[]).add(bot);
    }

    return grouped;
  }

  Bot _botFromManifest(
      Map<String, dynamic> entry, Map<String, dynamic> manifest) {
    final language = _readString(manifest['language']) ??
        _readString(entry['language']) ??
        'unknown';
    final botName = _readString(manifest['bot_name']) ??
        _readString(manifest['botName']) ??
        _readString(entry['name']) ??
        'Bot senza nome';
    final description = _readString(manifest['description']) ?? '';
    final startCommand =
        _readString(manifest['start_command']) ??
            _readString(manifest['startCommand']) ??
            '';
    final version = _readString(manifest['version']) ?? '';
    final author = _readString(manifest['author']);
    final permissions = _readStringList(manifest['permissions']);
    final tags = _readStringList(manifest['tags']);
    final archiveSha = _readString(entry['archiveSha256']) ??
        _readString(manifest['archive_sha256']) ??
        _readString(manifest['archiveSha256']);
    final compat = BotCompat.fromJson(manifest['compat']);
    final manifestUrl = _readString(entry['manifestUrl']);
    final fallbackSlug = botName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final sourcePath = manifestUrl != null && manifestUrl.isNotEmpty
        ? 'cdn:$manifestUrl'
        : 'cdn:$language/$fallbackSlug';

    return Bot(
      botName: botName,
      description: description,
      startCommand: startCommand,
      sourcePath: sourcePath,
      language: language,
      compat: compat,
      permissions: permissions,
      archiveSha256: archiveSha,
      version: version,
      author: author,
      tags: tags,
    );
  }

  String? _readString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isNotEmpty ? trimmed : null;
    }
    if (value != null) {
      final str = value.toString().trim();
      return str.isNotEmpty ? str : null;
    }
    return null;
  }

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
