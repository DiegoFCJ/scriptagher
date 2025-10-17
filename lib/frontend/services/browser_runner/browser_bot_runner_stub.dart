import 'package:http/http.dart' as http;

import '../../models/bot.dart';
import 'browser_runner_models.dart';

abstract class BrowserBotRunnerDelegate {
  bool get isSupported;

  Future<BrowserRunnerSession> start(
    Bot bot, {
    required String baseUrl,
  });

  void dispose();
}

BrowserBotRunnerDelegate createBrowserRunner({http.Client? httpClient}) =>
    _UnsupportedBrowserBotRunner();

bool get browserRunnerSupported => false;

class _UnsupportedBrowserBotRunner implements BrowserBotRunnerDelegate {
  @override
  bool get isSupported => false;

  @override
  Future<BrowserRunnerSession> start(
    Bot bot, {
    required String baseUrl,
  }) {
    throw UnsupportedError('Browser runner not available on this platform');
  }

  @override
  void dispose() {}
}
