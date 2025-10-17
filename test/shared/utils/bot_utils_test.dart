import 'package:flutter_test/flutter_test.dart';
import 'package:scriptagher/shared/exceptions/bot_manifest_validation_exception.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';

void main() {
  group('BotUtils.validateBotManifest', () {
    test('accepts a valid manifest', () {
      final manifest = {
        'name': 'Example Bot',
        'version': '1.0.0',
        'permissions': ['filesystem', 'network'],
        'hash': 'a' * 64,
      };

      expect(() => BotUtils.validateBotManifest(manifest), returnsNormally);
    });

    test('throws when required fields are missing', () {
      final manifest = {
        'name': 'Example Bot',
        'version': '1.0.0',
        'permissions': ['filesystem'],
      };

      expect(
        () => BotUtils.validateBotManifest(manifest),
        throwsA(isA<BotManifestValidationException>()
            .having((e) => e.message, 'message', contains("'hash'"))),
      );
    });

    test('throws when permissions contain invalid entries', () {
      final manifest = {
        'name': 'Example Bot',
        'version': '1.0.0',
        'permissions': ['filesystem', ''],
        'hash': 'b' * 64,
      };

      expect(
        () => BotUtils.validateBotManifest(manifest),
        throwsA(isA<BotManifestValidationException>()
            .having((e) => e.message, 'message', contains('permissions'))),
      );
    });

    test('throws when hash is not 64 hexadecimal characters', () {
      final manifest = {
        'name': 'Example Bot',
        'version': '1.0.0',
        'permissions': ['filesystem'],
        'hash': 'invalid-hash',
      };

      expect(
        () => BotUtils.validateBotManifest(manifest),
        throwsA(isA<BotManifestValidationException>()
            .having((e) => e.message, 'message', contains('64-character'))),
      );
    });
  });
}
