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

    router.get('/bots/downloaded', botController.fetchDownloadedBots);

    router.post('/bots/upload', botController.uploadBot);

    router.post(
        '/bots/<language>/<botName>/start',
        (Request request, String language, String botName) =>
            botController.startBot(request, language, botName));

    router.post(
        '/bots/<language>/<botName>/stop',
        (Request request, String language, String botName) =>
            botController.stopBot(request, language, botName));

    router.post(
        '/bots/<language>/<botName>/kill',
        (Request request, String language, String botName) =>
            botController.killBot(request, language, botName));

    router.delete(
        '/bots/<language>/<botName>',
        (Request request, String language, String botName) =>
            botController.deleteBot(request, language, botName));

    return router;
  }
}
