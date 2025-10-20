import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriptagher/frontend/models/bot.dart';
import 'package:scriptagher/frontend/models/bot_filter.dart';
import 'package:scriptagher/frontend/services/bot_get_service.dart';
import 'package:scriptagher/frontend/widgets/pages/bot_detail_view.dart';

class FakeBotGetService extends BotGetService {
  FakeBotGetService({
    this.downloadedBots = const [],
    this.remoteBots = const [],
  }) : super(baseUrl: '');

  final List<Bot> downloadedBots;
  final List<Bot> remoteBots;

  Map<String, List<Bot>> _groupByLanguage(Iterable<Bot> bots) {
    final Map<String, List<Bot>> grouped = {};
    for (final bot in bots) {
      grouped.putIfAbsent(bot.language, () => <Bot>[]).add(bot);
    }
    return grouped;
  }

  @override
  Future<List<Bot>> fetchDownloadedBotsFlat({BotFilter? filter}) async {
    return downloadedBots;
  }

  @override
  Future<Map<String, List<Bot>>> fetchDownloadedBots({BotFilter? filter}) async {
    return _groupByLanguage(downloadedBots);
  }

  @override
  Future<Map<String, List<Bot>>> fetchOnlineBots({
    bool forceRefresh = false,
    BotFilter? filter,
  }) async {
    return _groupByLanguage(remoteBots);
  }

  @override
  Future<List<Bot>> fetchOnlineBotsFlat({
    bool forceRefresh = false,
    BotFilter? filter,
  }) async {
    return remoteBots;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = null;
  });

  testWidgets('Run button disabled when bot is not downloaded',
      (WidgetTester tester) async {
    final bot = Bot(
      botName: 'demo',
      description: 'Bot demo',
      startCommand: 'start.sh',
      sourcePath: '/remote/demo',
      language: 'python',
      compat: const BotCompat(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BotDetailView(
          bot: bot,
          baseUrl: 'http://127.0.0.1:65534',
          botGetService: FakeBotGetService(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    final runFinder = find.widgetWithText(ElevatedButton, 'Esegui');
    expect(runFinder, findsOneWidget);
    final ElevatedButton runButton = tester.widget(runFinder);
    expect(runButton.onPressed, isNull);
  });

  testWidgets('Run button disabled when desktop runtimes are missing',
      (WidgetTester tester) async {
    final compat = const BotCompat(
      desktopRuntimes: ['python'],
      missingDesktopRuntimes: ['python'],
    );
    final bot = Bot(
      botName: 'demo',
      description: 'Bot demo',
      startCommand: 'start.sh',
      sourcePath: '/data/remote/python/demo',
      language: 'python',
      compat: compat,
    );
    final fakeService = FakeBotGetService(
      downloadedBots: [bot],
      remoteBots: [bot],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BotDetailView(
          bot: bot,
          baseUrl: 'http://127.0.0.1:65534',
          botGetService: fakeService,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final runFinder = find.widgetWithText(ElevatedButton, 'Esegui');
    expect(runFinder, findsOneWidget);
    final ElevatedButton runButton = tester.widget(runFinder);
    expect(runButton.onPressed, isNull);
  });
}
