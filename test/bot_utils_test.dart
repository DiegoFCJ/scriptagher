import 'package:flutter_test/flutter_test.dart';
import 'package:scriptagher/shared/exceptions/bot_manifest_validation_exception.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';

void main() {
  group('BotUtils.validateBotManifest', () {
    test('returns manifest when all required fields are valid', () {
      final manifest = {
        'botName': 'ExampleBot',
        'version': '1.0.0',
        'permissions': ['filesystem', 'network'],
        'hash': 'abc123',
        'description': 'Sample bot',
      };

      final validated = BotUtils.validateBotManifest(manifest);

      expect(validated['botName'], 'ExampleBot');
      expect(validated['version'], '1.0.0');
      expect(validated['permissions'], ['filesystem', 'network']);
      expect(validated['hash'], 'abc123');
    });

    test('throws when required fields are missing or invalid', () {
      final manifest = {
        'name': '',
        'version': '',
        'permissions': [1, ''],
      };

      expect(
        () => BotUtils.validateBotManifest(manifest),
        throwsA(isA<BotManifestValidationException>()),
      );
    });
  });
}
