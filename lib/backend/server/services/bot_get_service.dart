import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/backend/server/api_integration/github_api.dart';
import '../models/bot.dart';
import '../db/bot_database.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'system_runtime_service.dart';

class BotGetService {
  final CustomLogger logger = CustomLogger();
  final BotDatabase botDatabase;
  final GitHubApi gitHubApi;
  final SystemRuntimeService systemRuntimeService;

  BotGetService(this.botDatabase, this.gitHubApi, this.systemRuntimeService);

  /// Fetches the list of all available bots from the remote API.
  Future<List<Bot>> fetchAvailableBots() async {
    try {
      logger.info('BotService', 'Fetching available bots list.');

      // Fetch the list of bots from GitHub API
      final rawData = await gitHubApi.fetchBotsList();

      // Lista per contenere tutti i bot
      List<Bot> allBots = [];

      for (var language in rawData.keys) {
        for (var botData in rawData[language]) {
          final botName = botData['botName'];
          final path = botData['path'];
          final tags = Bot.parseTags(botData['tags']);
          final author = Bot.parseOptionalString(botData['author']);
          final version = Bot.parseOptionalString(botData['version']);

          // Crea un bot con valori di fallback
          Bot bot = Bot(
            botName: botName,
            description: 'No description available',
            startCommand: 'No start command',
            sourcePath: path,
            language: language,
            tags: tags,
            author: author,
            version: version,
          );

          // Aggiorna ulteriormente con informazioni più precise
          final botDetails = await _getBotDetails(language, bot);

          allBots.add(botDetails);
        }
      }

      // Salva la lista dei bot nel database
      await botDatabase.insertBots(allBots);

      logger.info(
        'BotService',
        'Successfully saved ${allBots.length} bots to the database.',
      );

      return allBots;
    } catch (e) {
      logger.error('BotService', 'Error fetching bots: $e');
      rethrow;
    }
  }

  /// Returns the list of bots stored inside the local database (downloaded).
  Future<List<Bot>> fetchDownloadedBotsFromDb() async {
    try {
      logger.info('BotService', 'Fetching bots stored in the database.');
      return await botDatabase.getAllBots();
    } catch (e) {
      logger.error('BotService', 'Error fetching downloaded bots: $e');
      rethrow;
    }
  }

  /// Fetches the detailed information of a bot by extracting and reading the Bot.json inside the bot directory.
  Future<Bot> _getBotDetails(String language, Bot bot) async {
    try {
      // Ottieni i dettagli
      final botDetailsMap = await gitHubApi.fetchBotDetails(
        language,
        bot.botName,
      );

      final compat = BotCompat.fromManifest(botDetailsMap['compat']);
      BotCompat compatWithStatus = compat;

      if (compat.desktopRuntimes.isNotEmpty) {
        final results = await systemRuntimeService.ensureRuntimes(
          compat.desktopRuntimes,
        );
        final missing = results.entries
            .where((entry) => entry.value == false)
            .map((entry) => entry.key)
            .toList();
        compatWithStatus = compat.copyWith(missingDesktopRuntimes: missing);
      }

      final description = botDetailsMap['description'] ?? bot.description;
      final startCommand = botDetailsMap['startCommand'] ??
          botDetailsMap['entrypoint'] ??
          bot.startCommand;

      final metadata = _extractMetadata(botDetailsMap);
      final tags = metadata.tags.isNotEmpty ? metadata.tags : bot.tags;
      final author = metadata.author ?? bot.author;
      final version = metadata.version ?? bot.version;

      bot = bot.copyWith(
        description: description,
        startCommand: startCommand,
        compat: compatWithStatus,
        tags: tags,
        author: author,
        version: version,
      );
      return bot;
    } catch (e) {
      logger.error(
        'BotService',
        'Error fetching details for ${bot.botName}: $e',
      );
      return bot; // Fallisce solo parzialmente, ritorna comunque il bot senza aggiornamenti
    }
  }

  // --------------------------------------- LOCAL BOTS --------------------------------------- \\
  // Funzione per caricare bot locali da DB e cartella filesystem
  Future<List<Bot>> fetchLocalBotsFromFilesystem() async {
    logger.info('BotService', 'Loading bots from local filesystem.');

    final localBotsFromFs = await _loadBotsFromLocalFolder();

    // Aggiorna la tabella locale per mantenere i dati sincronizzati.
    await botDatabase.clearLocalBots();
    await botDatabase.insertLocalBots(localBotsFromFs);

    return localBotsFromFs;
  }

  Future<List<Bot>> fetchLocalBotsFromDbAndFs() async {
    List<Bot> localBots = [];

    final hasLocal = await botDatabase.hasLocalBots();
    if (hasLocal) {
      localBots = await botDatabase.getLocalBots();
    }

    final localBotsFromFs = await fetchLocalBotsFromFilesystem();

    Map<String, Bot> uniqueBots = {};
    for (var b in localBots) {
      uniqueBots['${b.language}_${b.botName}'] = b;
    }
    for (var b in localBotsFromFs) {
      uniqueBots['${b.language}_${b.botName}'] = b;
    }

    return uniqueBots.values.toList();
  }

  // Funzione helper che legge la struttura localbots dal filesystem
  Future<List<Bot>> _loadBotsFromLocalFolder() async {
    final List<Bot> bots = [];
    final rootDir = Directory('localbots');

    if (!await rootDir.exists()) return bots;

    final languageDirs = await rootDir.list().toList();
    for (var langDir in languageDirs.whereType<Directory>()) {
      final language = p.basename(langDir.path);
      final botDirs = await langDir.list().toList();

      for (var botDir in botDirs.whereType<Directory>()) {
        final botName = p.basename(botDir.path);

        // Cerca file sorgente nel botDir (esempio: il primo file con estensione)
        final filesList = await botDir.list().toList();
        final files = filesList.whereType<File>().toList();

        if (files.isEmpty) continue;

        final sourceFile = files.first;
        final startCommand =
            ''; // qui potresti decidere come dedurlo, oppure lascialo vuoto

        final bot = Bot(
          botName: botName,
          description: 'Local bot from filesystem',
          startCommand: startCommand,
          sourcePath: sourceFile.path,
          language: language,
          tags: const [],
        );

        bots.add(bot);
      }
    }

    return bots;
  }

  _BotMetadata _extractMetadata(Map<String, dynamic> botDetailsMap) {
    final metadata = botDetailsMap['metadata'];
    final tags = _mergeTags(
      Bot.parseTags(botDetailsMap['tags']),
      Bot.parseTags(metadata is Map<String, dynamic> ? metadata['tags'] : null),
    );
    final author = Bot.parseOptionalString(
          metadata is Map<String, dynamic> ? metadata['author'] : null,
        ) ??
        Bot.parseOptionalString(botDetailsMap['author']);
    final version = Bot.parseOptionalString(
          metadata is Map<String, dynamic> ? metadata['version'] : null,
        ) ??
        Bot.parseOptionalString(botDetailsMap['version']);

    return _BotMetadata(tags: tags, author: author, version: version);
  }

  List<String> _mergeTags(List<String> first, List<String> second) {
    final Set<String> merged = {...first, ...second};
    final List<String> sorted = merged.toList()..sort();
    return sorted;
  }
}

class _BotMetadata {
  final List<String> tags;
  final String? author;
  final String? version;

  const _BotMetadata({this.tags = const [], this.author, this.version});
}
