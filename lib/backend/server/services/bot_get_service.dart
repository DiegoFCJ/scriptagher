import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scriptagher/backend/server/api_integration/github_api.dart';
import 'package:scriptagher/shared/constants/APIS.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';
import '../db/bot_database.dart';
import '../models/bot.dart';
import 'system_runtime_service.dart';

class BotGetService {
  final CustomLogger logger = CustomLogger();
  final BotDatabase botDatabase;
  final GitHubApi gitHubApi;
  final SystemRuntimeService systemRuntimeService;

  static const Duration _cacheDuration = Duration(minutes: 15);

  BotGetService(
      this.botDatabase, this.gitHubApi, this.systemRuntimeService);

  /// Fetches the list of all available bots from the remote API.
  Future<List<Bot>> fetchAvailableBots({bool forceRefresh = false}) async {
    try {
      logger.info('BotService', 'Fetching available bots list.');

      if (!forceRefresh) {
        final lastFetch = await botDatabase.getLastRemoteFetch();
        if (lastFetch != null) {
          final isFresh = DateTime.now().toUtc().difference(lastFetch) <=
              _cacheDuration;
          if (isFresh) {
            final cachedBots = await botDatabase.getAllBots();
            if (cachedBots.isNotEmpty) {
              logger.info('BotService',
                  'Serving ${cachedBots.length} bots from cache (last fetch at $lastFetch).');
              return cachedBots;
            }
          }
        }
      }

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
            author: 'Sconosciuto',
            version: '0.0.0',
          );

          // Aggiorna ulteriormente con informazioni più precise
          final botDetails = await _getBotDetails(language, bot);

          allBots.add(botDetails);
        }
      }

      // Salva la lista dei bot nel database
      await botDatabase.insertBots(allBots);
      await botDatabase.setLastRemoteFetch(DateTime.now());

      logger.info('BotService',
          'Successfully saved ${allBots.length} bots to the database.');

      return allBots;
    } catch (e) {
      logger.error('BotService', 'Error fetching bots: $e');
      if (!forceRefresh) {
        final cachedBots = await botDatabase.getAllBots();
        if (cachedBots.isNotEmpty) {
          logger.warn('BotService',
              'Returning cached bots after fetch failure (${cachedBots.length} bots).');
          return cachedBots;
        }
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
      final permissions = (botDetailsMap['permissions'] as List?)
              ?.whereType<String>()
              .toList() ??
          const <String>[];
      final archiveSha256 = botDetailsMap['archiveSha256'] as String?;
      final author = (botDetailsMap['author'] as String?)?.trim();
      final version = (botDetailsMap['version'] as String?)?.trim();
      final platforms = _derivePlatformCompatibility(compatWithStatus);

      bot = bot.copyWith(
        author: author ?? bot.author,
        version: version ?? bot.version,
        description: description,
        startCommand: startCommand,
        compat: compatWithStatus,
        permissions: permissions,
        platformCompatibility: platforms,
        archiveSha256: archiveSha256,
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
    final Map<String, Bot> bots = {};
    final rootCandidates = <Directory>[
      Directory(APIS.BOT_DIR_DATA_LOCAL),
      Directory('localbots'),
    ];

    for (final root in rootCandidates) {
      if (!await root.exists()) continue;

      final languageDirs = await root.list().toList();
      for (var langDir in languageDirs.whereType<Directory>()) {
        final language = p.basename(langDir.path);
        final botDirs = await langDir.list().toList();

        for (var botDir in botDirs.whereType<Directory>()) {
          final manifestFile =
              File(p.join(botDir.path, APIS.BOT_FILE_CONFIG));
          Bot? bot;

          if (await manifestFile.exists()) {
            try {
              final manifest =
                  await BotUtils.fetchBotDetails(manifestFile.path);
              final manifestLanguage =
                  (manifest['language'] as String?)?.trim();
              final botName =
                  (manifest['botName'] as String?)?.trim() ??
                      p.basename(botDir.path);
              final description =
                  (manifest['description'] as String?)?.trim() ??
                      'Local bot from filesystem';
              final startCommand =
                  (manifest['startCommand'] ?? manifest['entrypoint'])
                          as String? ??
                      '';
              final compat = BotCompat.fromManifest(manifest['compat']);
              final permissions = (manifest['permissions'] as List?)
                      ?.whereType<String>()
                      .toList() ??
                  const <String>[];
              final archiveSha = manifest['archiveSha256']?.toString();
              final author = (manifest['author'] as String?)?.trim();
              final version = (manifest['version'] as String?)?.trim();
              final platforms = _derivePlatformCompatibility(compat);

              bot = Bot(
                botName: botName,
                description: description,
                startCommand: startCommand,
                sourcePath: manifestFile.path,
                language: manifestLanguage?.isNotEmpty == true
                    ? manifestLanguage!
                    : language,
                compat: compat,
                permissions: permissions,
                archiveSha256: archiveSha,
                author: author ?? 'Sconosciuto',
                version: version ?? '0.0.0',
                platformCompatibility: platforms,
              );
            } catch (e) {
              logger.warn('BotService',
                  'Failed to parse manifest ${manifestFile.path}: $e');
            }
          }

          bot ??= Bot(
            botName: p.basename(botDir.path),
            description: 'Local bot from filesystem',
            startCommand: '',
            sourcePath: botDir.path,
            language: language,
            author: 'Sconosciuto',
            version: '0.0.0',
          );

          bots['${bot.language}_${bot.botName}'] = bot;
        }
      }
    }

    return bots.values.toList();
  }

  List<String> _derivePlatformCompatibility(BotCompat compat) {
    final platforms = <String>{};
    if (compat.desktopRuntimes.isNotEmpty) {
      platforms.add('desktop');
    }
    if (compat.browserSupported == true) {
      platforms.add('browser');
    }
    return platforms.toList(growable: false);
  }
}
