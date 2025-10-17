import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/constants/permissions.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import '../db/bot_database.dart';
import '../exceptions/authorization_exception.dart';
import '../models/bot.dart';

class BotExecutionService {
  final CustomLogger logger = CustomLogger();
  final BotDatabase botDatabase;

  BotExecutionService(this.botDatabase);

  Future<Bot> _loadBot(String language, String botName) async {
    final bot = await botDatabase.getBotByName(botName, language);
    if (bot == null) {
      throw AuthorizationException(
          'Bot $language/$botName non trovato. Installarlo prima di eseguirlo.');
    }
    return bot;
  }

  Future<void> executeBot(
      String language, String botName, List<String> grantedPermissions) async {
    final bot = await _loadBot(language, botName);

    final missingPermissions = bot.permissions
        .where((permission) => !grantedPermissions.contains(permission))
        .toList();

    if (missingPermissions.isNotEmpty) {
      throw AuthorizationException(
          'Permessi mancanti: ${missingPermissions.join(', ')}');
    }

    if (bot.permissions.contains(BotPermissions.filesystem) &&
        !grantedPermissions.contains(BotPermissions.filesystem)) {
      throw AuthorizationException(
          'Accesso al file system negato per il bot ${bot.botName}.');
    }

    logger.info(LOGS.EXECUTION_SERVICE,
        'Autorizzazione concessa per ${bot.botName}. Inizio esecuzione.');

    // TODO: implementare l'effettiva esecuzione del bot in futuro
  }
}
