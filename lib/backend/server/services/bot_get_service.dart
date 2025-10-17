import 'dart:convert';
import 'dart:io';

import 'package:scriptagher/backend/server/api_integration/github_api.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:path/path.dart' as p;

import '../db/bot_database.dart';
import '../models/bot.dart';

class BotGetService {
  final CustomLogger logger = CustomLogger();
  final BotDatabase botDatabase;
  final GitHubApi gitHubApi;

  BotGetService(this.botDatabase, this.gitHubApi);

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
          final botName = botData['botName'];
          final path = botData['path'];

          // Crea un bot con valori di fallback
          Bot bot = Bot(
            botName: botName,
            description: 'No description available',
            startCommand: 'No start command',
            sourcePath: path,
            language: language,
            author: botData['author'] ?? '',
            version: botData['version'] ?? '',
            permissions: _asStringList(botData['permissions']),
            platformCompatibility:
                _asStringList(botData['platform_compatibility']),
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

      bot = bot.copyWith(
        description: botDetailsMap['description'],
        startCommand: botDetailsMap['startCommand'],
        author: botDetailsMap['author'],
        version: botDetailsMap['version'],
        permissions: _asStringList(botDetailsMap['permissions'] ??
            botDetailsMap['requiredPermissions']),
        platformCompatibility: _asStringList(botDetailsMap[
                'platform_compatibility'] ??
            botDetailsMap['platformCompatibility']),
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
          author: 'Locale',
          version: '',
        );

        bots.add(bot);
      }
    }

    return bots;
  }

  List<String> _asStringList(dynamic value) {
    if (value == null) {
      return [];
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return [];
  }
}
