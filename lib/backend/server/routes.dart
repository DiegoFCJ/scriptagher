import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'controllers/bot_controller.dart';

class BotRoutes {
  final BotController botController;

  BotRoutes(this.botController);

  Router get router {
    final router = Router();

    router.get(
        '/bots/<language>/<botName>',
        (Request request, String language, String botName) =>
            botController.downloadBot(request, language, botName));

    router.get('/bots',
        (Request request) => botController.fetchAvailableBots(request));

    router.get('/localbots', botController.fetchLocalBots);

    router.post('/bots/start', botController.startBot);

    return router;
  }
}
