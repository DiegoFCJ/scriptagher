import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/backend/server/api_integration/github_api.dart';
import '../models/bot.dart';
import '../db/bot_database.dart';

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
      );
      return bot;
    } catch (e) {
      logger.error(
          'BotService', 'Error fetching details for ${bot.botName}: $e');
      return bot; // Fallisce solo parzialmente, ritorna comunque il bot senza aggiornamenti
    }
  }
}
