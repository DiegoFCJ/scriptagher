import 'dart:async';

import '../../models/bot.dart';
import 'browser_bot_runner_base.dart';

class _UnsupportedSession implements BrowserBotSession {
  final StreamController<BotSandboxMessage> _controller =
      StreamController<BotSandboxMessage>.broadcast();

  _UnsupportedSession(String reason) {
    _controller.add(BotSandboxMessage.stderr(reason));
    _controller.close();
  }

  @override
  Future<void> get completed => Future.value();

  @override
  Stream<BotSandboxMessage> get messages => _controller.stream;

  @override
  void terminate() {}
}

class _UnsupportedRunner implements BrowserBotRunner {
  @override
  bool canRun(Bot bot) => false;

  @override
  void dispose() {}

  @override
  BrowserBotSession run(Bot bot) {
    return _UnsupportedSession(
        'Browser execution is not supported on this platform.');
  }
}

BrowserBotRunner createBrowserBotRunner() => _UnsupportedRunner();
