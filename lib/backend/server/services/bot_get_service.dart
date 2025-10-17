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

  static const Duration _defaultCacheDuration = Duration(minutes: 15);

  BotGetService(
      this.botDatabase, this.gitHubApi, this.systemRuntimeService);

  /// Fetches the list of all available bots from the remote API.
  Future<List<Bot>> fetchAvailableBots(
      {bool forceRefresh = false, Duration? cacheDuration}) async {
    final effectiveCacheDuration = cacheDuration ?? _defaultCacheDuration;
    final now = DateTime.now().toUtc();

    if (!forceRefresh) {
      final lastFetch = await botDatabase.getLastRemoteFetchAt();
      if (lastFetch != null) {
        final cacheAge = now.difference(lastFetch);
        if (cacheAge <= effectiveCacheDuration) {
          final cachedBots = await botDatabase.getAllBots();
          if (cachedBots.isNotEmpty) {
            logger.info('BotService',
                'Serving ${cachedBots.length} bots from cache (age: ${cacheAge.inSeconds}s).');
            return cachedBots;
          }
        }
      }
    }

    try {
      final remoteBots = await _fetchBotsFromRemote();
      await botDatabase.insertBots(remoteBots);
      await botDatabase.setLastRemoteFetchAt(now);
      logger.info('BotService',
          'Successfully saved ${remoteBots.length} bots to the database.');
      return remoteBots;
    } catch (e) {
      logger.error('BotService', 'Error fetching bots: $e');
      if (forceRefresh) {
        rethrow;
      }

      try {
        final cachedBots = await botDatabase.getAllBots();
        if (cachedBots.isNotEmpty) {
          logger.warn('BotService',
              'Returning ${cachedBots.length} cached bots due to remote error.');
          return cachedBots;
        }
      } catch (cacheError) {
        logger.error('BotService', 'Error accessing cached bots: $cacheError');
      }

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
      final botDetailsMap =
          await gitHubApi.fetchBotDetails(language, bot.botName);

      final compat = BotCompat.fromManifest(botDetailsMap['compat']);
      BotCompat compatWithStatus = compat;

      if (compat.desktopRuntimes.isNotEmpty) {
        final results =
            await systemRuntimeService.ensureRuntimes(compat.desktopRuntimes);
        final missing = results.entries
            .where((entry) => entry.value == false)
            .map((entry) => entry.key)
            .toList();
        compatWithStatus = compat.copyWith(
          missingDesktopRuntimes: missing,
        );
      }

      final description = botDetailsMap['description'] ?? bot.description;
      final startCommand = botDetailsMap['startCommand'] ??
          botDetailsMap['entrypoint'] ??
          bot.startCommand;

      bot = bot.copyWith(
        description: description,
        startCommand: startCommand,
        compat: compatWithStatus,
      );
      return bot;
    } catch (e) {
      logger.error(
          'BotService', 'Error fetching details for ${bot.botName}: $e');
      return bot; // Fallisce solo parzialmente, ritorna comunque il bot senza aggiornamenti
    }
  }

  Future<List<Bot>> _fetchBotsFromRemote() async {
    logger.info('BotService', 'Fetching available bots list from remote API.');
    final rawData = await gitHubApi.fetchBotsList();

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
        );

        // Aggiorna ulteriormente con informazioni più precise
        final botDetails = await _getBotDetails(language, bot);

        allBots.add(botDetails);
      }
    }

    return allBots;
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
        final startCommand = ''; // qui potresti decidere come dedurlo, oppure lascialo vuoto

        final bot = Bot(
          botName: botName,
          description: 'Local bot from filesystem',
          startCommand: startCommand,
          sourcePath: sourceFile.path,
          language: language,
        );

        bots.add(bot);
      }
    }

    return bots;
  }
}
