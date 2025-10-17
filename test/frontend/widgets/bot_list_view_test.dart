import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scriptagher/frontend/models/bot.dart';
import 'package:scriptagher/frontend/services/bot_get_service.dart';
import 'package:scriptagher/frontend/widgets/pages/bot_list_view.dart';

class _FakeBotService extends BotGetService {
  final Map<String, List<Bot>> _data;

  _FakeBotService(this._data) : super(baseUrl: '');

  @override
  Future<Map<String, List<Bot>>> fetchDownloadedBots(
      {BotFilter? filter}) async {
    return _maybeFilter(filter);
  }

  @override
  Future<Map<String, List<Bot>>> fetchLocalBots({BotFilter? filter}) async {
    return _maybeFilter(filter);
  }

  @override
  Future<Map<String, List<Bot>>> fetchOnlineBots({BotFilter? filter}) async {
    return _maybeFilter(filter);
  }

  Map<String, List<Bot>> _maybeFilter(BotFilter? filter) {
    return filter == null ? _data : filterGroupedBots(_data, filter);
  }
}

void main() {
  group('BotList filters', () {
    late Map<String, List<Bot>> grouped;

    Bot buildBot({
      required String name,
      required String language,
      List<String> tags = const [],
      String? author,
      String? version,
    }) {
      return Bot(
        botName: name,
        description: 'Descrizione di $name',
        startCommand: 'run',
        sourcePath: 'source/$name',
        language: language,
        tags: tags,
        author: author,
        version: version,
      );
    }

    setUp(() {
      grouped = {
        'Python': [
          buildBot(
            name: 'AlphaBot',
            language: 'Python',
            tags: const ['chat', 'assistant'],
            author: 'Alice',
            version: '1.0.0',
          ),
          buildBot(
            name: 'GammaBot',
            language: 'Python',
            tags: const ['analysis'],
            author: 'Bob',
            version: '0.9.0',
          ),
        ],
        'Dart': [
          buildBot(
            name: 'BetaBot',
            language: 'Dart',
            tags: const ['automation'],
            author: 'Carol',
            version: '2.0.0',
          ),
        ],
      };
    });

    testWidgets('search and tag filters update language groups',
        (tester) async {
      final service = _FakeBotService(grouped);

      await tester.pumpWidget(
        MaterialApp(
          home: BotList(botGetService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Python'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'gamma');
      await tester.pumpAndSettle();

      expect(find.text('Dart'), findsNothing);
      expect(find.text('Python'), findsOneWidget);
      expect(find.text('Nessun bot corrisponde ai filtri correnti.'),
          findsNothing);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Dart'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'chat'));
      await tester.pumpAndSettle();

      expect(find.text('Dart'), findsNothing);
      expect(find.text('Reset filtri'), findsOneWidget);

      await tester.tap(find.text('Reset filtri'));
      await tester.pumpAndSettle();

      expect(find.text('Dart'), findsOneWidget);
    });
  });
}
