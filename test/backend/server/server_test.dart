import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

import 'package:scriptagher/backend/server/server.dart';

void main() {
  group('CORS middleware', () {
    test('responds to OPTIONS requests with default CORS headers', () async {
      final Handler handler = const Pipeline()
          .addMiddleware(createMiddleware())
          .addHandler((Request _) => Response.ok('OK'));

      final Response response =
          await handler(Request('OPTIONS', Uri.parse('http://localhost/test')));

      expect(response.statusCode, equals(200));
      expect(response.headers['Access-Control-Allow-Origin'], equals('*'));
      expect(response.headers['Access-Control-Allow-Methods'], contains('OPTIONS'));
      expect(response.headers['Access-Control-Allow-Headers'], contains('Content-Type'));
      expect(await response.readAsString(), isEmpty);
    });

    test('adds CORS headers to streaming responses without removing existing ones',
        () async {
      final Handler handler = const Pipeline()
          .addMiddleware(createMiddleware())
          .addHandler((Request _) {
        final Stream<List<int>> stream = Stream<List<int>>.fromIterable(
          <List<int>>[utf8.encode('data: test\\n\\n')],
        );
        return Response.ok(
          stream,
          headers: const <String, String>{
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
          },
        );
      });

      final Response response =
          await handler(Request('GET', Uri.parse('http://localhost/stream')));

      expect(response.headers['Access-Control-Allow-Origin'], equals('*'));
      expect(response.headers['Access-Control-Allow-Methods'], isNotEmpty);
      expect(response.headers['Access-Control-Allow-Headers'], isNotEmpty);
      expect(response.headers['Content-Type'], 'text/event-stream');
      expect(response.headers['Cache-Control'], 'no-cache');
      expect(response.headers['Connection'], 'keep-alive');
    });
  });
}
