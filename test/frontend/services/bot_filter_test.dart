import 'package:flutter_test/flutter_test.dart';
import 'package:scriptagher/frontend/models/bot.dart';
import 'package:scriptagher/frontend/models/bot_filter.dart';
import 'package:scriptagher/frontend/services/bot_get_service.dart';

void main() {
  group('BotFilter', () {
    test('fromQuery parses tokens into filter fields', () {
      const query =
          'lang:python tag:utility #files author:"Jane Doe" version:1.0.0';
      final filter = BotFilter.fromQuery(query);

      expect(filter.languages, equals(['python']));
      expect(filter.tags, containsAll(['utility', 'files']));
      expect(filter.authors, equals(['jane doe']));
      expect(filter.versions, equals(['1.0.0']));
      expect(filter.searchTerm, isEmpty);
    });

    test('matches returns true when bot satisfies search term and filters', () {
      final bot = Bot(
        botName: 'UtilityBot',
        description: 'A helpful utility bot for files',
        startCommand: 'run',
        sourcePath: '/tmp',
        language: 'python',
        version: '1.0.1',
        author: 'Jane Doe',
        tags: const ['utility', 'files'],
      );

      final filter = BotFilter.fromQuery('utility version:1.0 author:jane');

      expect(filter.matches(bot), isTrue);
    });

    test('matches returns false when required tag is missing', () {
      final bot = Bot(
        botName: 'UtilityBot',
        description: 'A helpful utility bot for files',
        startCommand: 'run',
        sourcePath: '/tmp',
        language: 'python',
        version: '1.0.1',
        author: 'Jane Doe',
        tags: const ['utility'],
      );

      final filter = BotFilter.fromQuery('tag:files');

      expect(filter.matches(bot), isFalse);
    });
  });

  group('BotGetService.applyFilter', () {
    test('returns filtered groups respecting metadata filters', () {
      final service = BotGetService();
      final botPython = Bot(
        botName: 'UtilityBot',
        description: 'A helpful utility bot for files',
        startCommand: 'run',
        sourcePath: '/tmp',
        language: 'python',
        version: '1.0.1',
        author: 'Jane Doe',
        tags: const ['utility', 'files'],
      );
      final botJs = Bot(
        botName: 'BrowserBot',
        description: 'Automates browser tasks',
        startCommand: 'run',
        sourcePath: '/tmp',
        language: 'javascript',
        version: '2.0.0',
        author: 'John Smith',
        tags: const ['web'],
      );

      final grouped = {
        'python': [botPython],
        'javascript': [botJs],
      };

      final filter = BotFilter.fromQuery('lang:python tag:utility');
      final filtered = service.applyFilter(grouped, filter);

      expect(filtered.keys, equals(['python']));
      expect(filtered['python'], isNotNull);
      expect(filtered['python']!.single.botName, equals('UtilityBot'));
      expect(filtered.containsKey('javascript'), isFalse);
    });

    test('returns original map when filter is empty', () {
      final service = BotGetService();
      final bot = Bot(
        botName: 'UtilityBot',
        description: 'A helpful utility bot for files',
        startCommand: 'run',
        sourcePath: '/tmp',
        language: 'python',
      );

      final grouped = {'python': [bot]};
      final filtered = service.applyFilter(grouped, const BotFilter());

      expect(filtered, equals(grouped));
    });
  });
}
