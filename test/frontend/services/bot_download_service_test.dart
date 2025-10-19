import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scriptagher/frontend/models/bot.dart';
import 'package:scriptagher/frontend/services/bot_download_service.dart';

void main() {
  group('BotDownloadService', () {
    test('deleteBot calls DELETE endpoint successfully', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 204);
      });

      final service = BotDownloadService(
        baseUrl: 'http://localhost:8080',
        httpClient: client,
      );

      await service.deleteBot('python', 'SampleBot');

      expect(capturedRequest.method, equals('DELETE'));
      expect(capturedRequest.url.path,
          equals('/bots/python/SampleBot'));
    });

    test('deleteBot throws with backend message on error', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Errore personalizzato'}), 400);
      });

      final service = BotDownloadService(
        baseUrl: 'http://localhost:8080',
        httpClient: client,
      );

      expect(
        () => service.deleteBot('python', 'BrokenBot'),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'message', contains('Errore personalizzato'))),
      );
    });

    test('downloadBot parses successful response', () async {
      final client = MockClient((request) async {
        final payload = {
          'id': 1,
          'bot_name': 'SampleBot',
          'description': 'Desc',
          'start_command': 'run.sh',
          'source_path': 'data/remote/python/SampleBot/Bot.json',
          'language': 'python',
          'compat': const BotCompat().toJson(),
          'permissions': const <String>[],
          'archive_sha256': 'abc',
          'version': '1.0.0',
          'author': 'Author',
          'tags': const <String>[],
        };
        return http.Response(jsonEncode(payload), 200);
      });

      final service = BotDownloadService(
        baseUrl: 'http://localhost:8080',
        httpClient: client,
      );

      final bot = await service.downloadBot('python', 'SampleBot');

      expect(bot.botName, equals('SampleBot'));
      expect(bot.language, equals('python'));
      expect(bot.isDownloaded, isTrue);
    });
  });
}
