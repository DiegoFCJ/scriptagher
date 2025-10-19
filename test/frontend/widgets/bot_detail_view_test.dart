import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriptagher/frontend/models/bot.dart';
import 'package:scriptagher/frontend/widgets/pages/bot_detail_view.dart';

void main() {
  Bot createBot({BotCompat compat = const BotCompat(), String? sourcePath}) {
    return Bot(
      botName: 'Test Bot',
      description: 'desc',
      startCommand: 'run',
      sourcePath: sourcePath ?? '/data/remote/test',
      language: 'python',
      compat: compat,
    );
  }

  Future<State<StatefulWidget>> pumpDetailView(
      WidgetTester tester, Bot bot) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BotDetailView(bot: bot),
        ),
      ),
    );
    await tester.pump();
    final element = tester.element(find.byType(BotDetailView));
    return (element as StatefulElement).state;
  }

  testWidgets('execute button is disabled when bot is not downloaded',
      (tester) async {
    final bot = createBot();
    final state = await pumpDetailView(tester, bot) as dynamic;

    state.debugConfigureForTesting(
      remoteBot: bot,
      updateRemoteBot: true,
      downloadedBot: null,
      updateDownloadedBot: true,
      isDownloaded: false,
      updateActiveProcessId: true,
      activeProcessId: null,
    );
    await tester.pump();

    final executeFinder = find.widgetWithText(ElevatedButton, 'Esegui');
    expect(executeFinder, findsOneWidget);
    final ElevatedButton executeButton = tester.widget(executeFinder);
    expect(executeButton.onPressed, isNull);

    final tooltipFinder =
        find.ancestor(of: executeFinder, matching: find.byType(Tooltip));
    expect(tooltipFinder, findsOneWidget);
    final Tooltip tooltip = tester.widget(tooltipFinder);
    expect(tooltip.message, contains('Scarica il bot'));
  });

  testWidgets(
      'execute button is disabled when required desktop runtimes are missing',
      (tester) async {
    const compat = BotCompat(
      desktopRuntimes: ['python'],
      missingDesktopRuntimes: ['python'],
    );
    final bot = createBot(compat: compat, sourcePath: '/data/remote/test');
    final state = await pumpDetailView(tester, bot) as dynamic;

    state.debugConfigureForTesting(
      remoteBot: bot,
      updateRemoteBot: true,
      downloadedBot: bot,
      updateDownloadedBot: true,
      isDownloaded: true,
      updateActiveProcessId: true,
      activeProcessId: null,
    );
    await tester.pump();

    final executeFinder = find.widgetWithText(ElevatedButton, 'Esegui');
    expect(executeFinder, findsOneWidget);
    final ElevatedButton executeButton = tester.widget(executeFinder);
    expect(executeButton.onPressed, isNull);

    final tooltipFinder =
        find.ancestor(of: executeFinder, matching: find.byType(Tooltip));
    expect(tooltipFinder, findsOneWidget);
    final Tooltip tooltip = tester.widget(tooltipFinder);
    expect(tooltip.message, contains('Runtime mancanti'));
  });
}
