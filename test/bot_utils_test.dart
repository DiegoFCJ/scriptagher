import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';

void main() {
  const archiveHash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const validManifest = {
    'botName': 'SampleBot',
    'version': '1.2.3',
    'archiveSha256': archiveHash,
    'permissions': ['network', 'filesystem:read']
  };

  group('BotUtils.parseManifestContent', () {
    test('returns normalized manifest for valid content', () {
      final manifestJson = json.encode(validManifest);

      final result = BotUtils.parseManifestContent(manifestJson);

      expect(result['botName'], equals('SampleBot'));
      expect(result['version'], equals('1.2.3'));
      expect(result['archiveSha256'], equals(archiveHash.toLowerCase()));
      expect(result['permissions'], equals(validManifest['permissions']));
    });

    test('accepts name alias for botName', () {
      final manifestWithAlias = Map<String, dynamic>.from(validManifest)
        ..remove('botName')
        ..['name'] = 'AliasBot';
      final manifestJson = json.encode(manifestWithAlias);

      final result = BotUtils.parseManifestContent(manifestJson);

      expect(result['botName'], equals('AliasBot'));
    });

    test('throws when botName is missing', () {
      final manifest = Map<String, dynamic>.from(validManifest)
        ..remove('botName');
      final manifestJson = json.encode(manifest);

      expect(
        () => BotUtils.parseManifestContent(manifestJson),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('botName'))),
      );
    });

    test('throws when version is empty', () {
      final manifest = Map<String, dynamic>.from(validManifest)
        ..['version'] = '  ';
      final manifestJson = json.encode(manifest);

      expect(
        () => BotUtils.parseManifestContent(manifestJson),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('version'))),
      );
    });

    test('throws when permissions contain invalid values', () {
      final manifest = Map<String, dynamic>.from(validManifest)
        ..['permissions'] = ['network', ''];
      final manifestJson = json.encode(manifest);

      expect(
        () => BotUtils.parseManifestContent(manifestJson),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('permissions'))),
      );
    });
  });
}
