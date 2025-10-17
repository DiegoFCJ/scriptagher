import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:scriptagher/backend/server/api_integration/github_api.dart';
import 'package:scriptagher/shared/constants/APIS.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/models/compat.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';

import '../db/bot_database.dart';
import '../models/bot.dart';
import '../utils/compat_extensions.dart';
import 'system_runtime_service.dart';

class BotGetService {
  final CustomLogger logger = CustomLogger();
  final BotDatabase botDatabase;
  final GitHubApi gitHubApi;
  final SystemRuntimeService runtimeService;

  BotGetService(this.botDatabase, this.gitHubApi, this.runtimeService);

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

      final compat = CompatInfo.fromManifest(botDetailsMap['compat']);
      final evaluatedCompat = await compat.evaluateWith(runtimeService);

      bot = bot.copyWith(
        description: botDetailsMap['description']?.toString(),
        startCommand:
            (botDetailsMap['startCommand'] ?? botDetailsMap['entrypoint'] ?? '')
                .toString(),
        compat: evaluatedCompat,
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

        final botJsonPath = p.join(botDir.path, APIS.BOT_FILE_CONFIG);
        if (!await File(botJsonPath).exists()) {
          continue;
        }

        final botDetails = await BotUtils.fetchBotDetails(botJsonPath);
        final compat = CompatInfo.fromManifest(botDetails['compat']);
        final evaluatedCompat = await compat.evaluateWith(runtimeService);

        final bot = Bot(
          botName: (botDetails['botName'] ?? botName).toString(),
          description:
              botDetails['description']?.toString() ?? 'Local bot from filesystem',
          startCommand:
              (botDetails['startCommand'] ?? botDetails['entrypoint'] ?? '')
                  .toString(),
          sourcePath: botJsonPath,
          language: language,
          compat: evaluatedCompat,
        );

        bots.add(bot);
      }
    }

    return bots;
  }
}
