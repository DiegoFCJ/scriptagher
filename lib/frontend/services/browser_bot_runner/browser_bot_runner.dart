import 'browser_bot_runner_base.dart';
import 'browser_bot_runner_stub.dart'
    if (dart.library.html) 'browser_bot_runner_web.dart' as impl;

export 'browser_bot_runner_base.dart'
    show BrowserBotRunner, BrowserBotSession, BotSandboxMessage, BotSandboxMessageType;

BrowserBotRunner createBrowserBotRunner() => impl.createBrowserBotRunner();
