import 'package:flutter_test/flutter_test.dart';

import 'package:scriptagher/frontend/models/bot.dart';
import 'package:scriptagher/frontend/services/bot_get_service.dart';

void main() {
  group('BotGetService filtering', () {
    final service = BotGetService();

    final bots = [
      const Bot(
        botName: 'AlphaBot',
        description: 'Risolve problemi matematici',
        startCommand: 'python alpha.py',
        sourcePath: '/alpha',
        language: 'Python',
        tags: ['math', 'education'],
        author: 'Alice',
        version: '1.0.0',
      ),
      const Bot(
        botName: 'BetaHelper',
        description: 'Assistente di traduzione',
        startCommand: 'dart run beta',
        sourcePath: '/beta',
        language: 'Dart',
        tags: ['translation', 'language'],
        author: 'Bob',
        version: '2.1.0',
      ),
      const Bot(
        botName: 'GammaAI',
        description: 'Analisi dati avanzata',
        startCommand: 'node gamma.js',
        sourcePath: '/gamma',
        language: 'JavaScript',
        tags: ['analytics'],
        author: 'Alice',
        version: '1.5.0',
      ),
    ];

    final groupedBots = {
      'Python': [bots[0]],
      'Dart': [bots[1]],
      'JavaScript': [bots[2]],
    };

    test('filters by search query across metadata', () {
      final filters = const BotFilters(query: 'traduzione');
      final filtered = service.filterGroupedBots(groupedBots, filters);

      expect(filtered.length, 1);
      expect(filtered.values.first.single.botName, 'BetaHelper');
    });

    test('filters by language and tag combination', () {
      final filters = const BotFilters(language: 'python', tag: 'math');
      final filtered = service.filterGroupedBots(groupedBots, filters);

      expect(filtered.keys, contains('Python'));
      expect(filtered['Python']!.length, 1);
      expect(filtered['Python']!.first.botName, 'AlphaBot');

      final flatFiltered = service.filterBots(bots, filters);
      expect(flatFiltered.length, 1);
      expect(flatFiltered.first.botName, 'AlphaBot');
    });

    test('filters by author and version ignoring case', () {
      final filters = const BotFilters(author: 'alice', version: '1.5.0');
      final flatFiltered = service.filterBots(bots, filters);

      expect(flatFiltered.length, 1);
      expect(flatFiltered.first.botName, 'GammaAI');
    });
  });
}
