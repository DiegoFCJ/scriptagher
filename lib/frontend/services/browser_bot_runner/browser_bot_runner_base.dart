import '../../models/bot.dart';

enum BotSandboxMessageType { stdout, stderr, system }

class BotSandboxMessage {
  final BotSandboxMessageType type;
  final String message;

  const BotSandboxMessage(this.type, this.message);

  factory BotSandboxMessage.stdout(String message) =>
      BotSandboxMessage(BotSandboxMessageType.stdout, message);

  factory BotSandboxMessage.stderr(String message) =>
      BotSandboxMessage(BotSandboxMessageType.stderr, message);

  factory BotSandboxMessage.system(String message) =>
      BotSandboxMessage(BotSandboxMessageType.system, message);
}

abstract class BrowserBotSession {
  Stream<BotSandboxMessage> get messages;

  Future<void> get completed;

  void terminate();
}

abstract class BrowserBotRunner {
  bool canRun(Bot bot);

  BrowserBotSession run(Bot bot);

  void dispose();
}

BrowserBotRunner createBrowserBotRunner();
