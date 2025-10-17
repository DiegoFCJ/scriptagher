import 'package:http/http.dart' as http;

import '../../models/bot.dart';
import 'browser_runner_models.dart';
import 'browser_bot_runner_stub.dart'
    if (dart.library.html) 'browser_bot_runner_web.dart' as platform;

class BrowserBotRunner {
  BrowserBotRunner({http.Client? httpClient})
      : _delegate = platform.createBrowserRunner(httpClient: httpClient);

  final platform.BrowserBotRunnerDelegate _delegate;

  static bool get isSupported => platform.browserRunnerSupported;

  bool get isAvailable => _delegate.isSupported;

  Future<BrowserRunnerSession> start(
    Bot bot, {
    required String baseUrl,
  }) {
    return _delegate.start(bot, baseUrl: baseUrl);
  }

  void dispose() => _delegate.dispose();
}
