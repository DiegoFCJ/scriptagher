import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/backend/server/api_integration/github_api.dart';
import '../models/bot.dart';
import '../db/bot_database.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class BotGetService {
  final CustomLogger logger = CustomLogger();
  final BotDatabase botDatabase;
  final GitHubApi gitHubApi;

  BotGetService(this.botDatabase, this.gitHubApi);

  List<String> _parseTags(dynamic tags) {
    if (tags == null) return [];
    if (tags is List) {
      return tags.map((tag) => tag.toString()).toList();
    }
    if (tags is String && tags.isNotEmpty) {
      return tags
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Fetches the list of all available bots from the server.
  Future<List<Bot>> fetchAvailableBots() async {
    try {
      logger.info('BotService', 'Fetching available bots list.');

      // Fetch the list of bots from GitHub API
      final rawData = await gitHubApi.fetchBotsList();

      // Lista per contenere tutti i bot
      List<Bot> allBots = [];

      for (var language in rawData.keys) {
        for (var botData in rawData[language]) {
          final dynamic rawName = botData['botName'] ?? botData['name'];
          if (rawName == null) {
            logger.warn('BotService',
                'Bot entry without a valid name found for language $language');
            continue;
          }

          final botName = rawName.toString();
          final path = botData['path']?.toString() ?? '';
          final metadata =
              (botData['metadata'] as Map<String, dynamic>?) ??
                  const <String, dynamic>{};

          // Crea un bot con valori di fallback
          Bot bot = Bot(
            botName: botName,
            description: metadata['description'] ?? 'No description available',
            startCommand: metadata['startCommand'] ?? 'No start command',
            sourcePath: path,
            language: botData['language'] ?? language,
            tags: _parseTags(botData['tags'] ?? metadata['tags']),
            author: metadata['author']?.toString() ?? '',
            version: metadata['version']?.toString() ?? '',
          );

          // Aggiorna ulteriormente con informazioni più precise
          final botDetails = await _getBotDetails(language, bot);

          allBots.add(botDetails);
        }
      }

      // Salva la lista dei bot nel database
      await botDatabase.insertBots(allBots);

      logger.info('BotService',
          'Successfully saved ${allBots.length} bots to the database.');

      return allBots;
    } catch (e) {
      logger.error('BotService', 'Error fetching bots: $e');
      rethrow;
    }
  }

  /// Fetches the detailed information of a bot by extracting and reading the Bot.json inside the bot directory.
  Future<Bot> _getBotDetails(String language, Bot bot) async {
    try {
      // Ottieni i dettagli
      final botDetailsMap =
          await gitHubApi.fetchBotDetails(language, bot.botName);

      final metadata =
          (botDetailsMap['metadata'] as Map<String, dynamic>?) ??
              const <String, dynamic>{};

      bot = bot.copyWith(
        description: botDetailsMap['description'],
        startCommand: botDetailsMap['startCommand'],
        tags: _parseTags(botDetailsMap['tags'] ?? metadata['tags']),
        author: metadata['author']?.toString() ?? bot.author,
        version: metadata['version']?.toString() ?? bot.version,
      );
      return bot;
    } catch (e) {
      logger.error(
          'BotService', 'Error fetching details for ${bot.botName}: $e');
      return bot; // Fallisce solo parzialmente, ritorna comunque il bot senza aggiornamenti
    }
  }



  // --------------------------------------- LOCAL BOTS --------------------------------------- \\
  // Funzione per caricare bot locali da DB e cartella filesystem
  Future<List<Bot>> fetchLocalBotsFromDbAndFs() async {
    List<Bot> localBots = [];

    final hasLocal = await botDatabase.hasLocalBots();
    if (hasLocal) {
      localBots = await botDatabase.getLocalBots();
    }

    // Legge bot da filesystem
    final localBotsFromFs = await _loadBotsFromLocalFolder();

    // Unisci e aggiorna DB (per semplicità sovrascrivi)
    await botDatabase.clearLocalBots();
    await botDatabase.insertLocalBots(localBotsFromFs);

    // Ritorna lista unificata (evitando duplicati per nome+language)
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
        final startCommand = ''; // qui potresti decidere come dedurlo, oppure lascialo vuoto

        final bot = Bot(
          botName: botName,
          description: 'Local bot from filesystem',
          startCommand: startCommand,
          sourcePath: sourceFile.path,
          language: language,
          tags: const [],
          author: 'local',
          version: '',
        );

        bots.add(bot);
      }
    }

    return bots;
  }
}
