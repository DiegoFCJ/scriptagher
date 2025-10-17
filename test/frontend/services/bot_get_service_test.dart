import 'package:flutter_test/flutter_test.dart';
import 'package:scriptagher/frontend/models/bot.dart';
import 'package:scriptagher/frontend/services/bot_get_service.dart';

void main() {
  group('BotGetService.filterGroupedBots', () {
    late BotGetService service;
    late Map<String, List<Bot>> grouped;

    Bot buildBot({
      required String name,
      required String language,
      String description = '',
      List<String> tags = const [],
      String? author,
      String? version,
    }) {
      return Bot(
        botName: name,
        description: description,
        startCommand: 'run',
        sourcePath: 'source/$name',
        language: language,
        tags: tags,
        author: author,
        version: version,
      );
    }

    setUp(() {
      service = BotGetService();
      grouped = {
        'Python': [
          buildBot(
            name: 'AlphaBot',
            language: 'Python',
            description: 'Assistente per il terminale',
            tags: const ['utility', 'chat'],
            author: 'Alice',
            version: '1.0.0',
          ),
          buildBot(
            name: 'GammaBot',
            language: 'Python',
            description: 'Analisi dati',
            tags: const ['data'],
            author: 'Bob',
            version: '0.9.0',
          ),
        ],
        'Dart': [
          buildBot(
            name: 'BetaBot',
            language: 'Dart',
            description: 'Automazione',
            tags: const ['automation'],
            author: 'Charlie',
            version: '2.0.0',
          ),
        ],
      };
    });

    test('returns original data when filter is null', () {
      final result = service.filterGroupedBots(grouped, null);
      expect(result, grouped);
    });

    test('filters by search query across fields', () {
      final filter = BotFilter(query: 'analisi');
      final result = service.filterGroupedBots(grouped, filter);
      expect(result.length, 1);
      expect(result['Python']!.map((bot) => bot.botName), ['GammaBot']);
    });

    test('filters by tags requiring all selections', () {
      final filter = BotFilter(tags: {'utility', 'chat'});
      final result = service.filterGroupedBots(grouped, filter);
      expect(result.length, 1);
      expect(result['Python']!.single.botName, 'AlphaBot');
    });

    test('filters by combined metadata', () {
      final filter = BotFilter(
        language: 'python',
        author: 'alice',
        version: '1.0.0',
      );
      final result = service.filterGroupedBots(grouped, filter);
      expect(result.length, 1);
      expect(result['Python']!.single.botName, 'AlphaBot');
    });
  });
}
