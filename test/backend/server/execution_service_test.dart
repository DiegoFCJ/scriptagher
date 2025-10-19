import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:scriptagher/backend/server/services/execution_service.dart';

void main() {
  group('ExecutionService lossy UTF-8 decoding', () {
    test('decodes malformed stdout bytes without throwing', () async {
      final malformedOutput = <List<int>>[
        <int>[102, 111, 111, 0xFF, 98, 97, 114, 10],
      ];
      final buffer = StringBuffer();

      await expectLater(
        Stream<List<int>>.fromIterable(malformedOutput)
            .transform(ExecutionService.lossyUtf8Decoder)
            .transform(const LineSplitter())
            .map((line) {
          buffer.writeln(line);
          return line;
        }).drain<void>(),
        completes,
      );

      expect(buffer.toString(), contains('�'));
    });

    test('decodes malformed bytes in SSE stream without throwing', () async {
      final controller = StreamController<List<int>>();

      final linesFuture = controller.stream
          .transform(ExecutionService.lossyUtf8Decoder)
          .transform(const LineSplitter())
          .toList();

      controller.add(<int>[0x61, 0x62, 0x63, 0xFF]);
      controller.add(<int>[0x64, 0x65, 0x66, 0x0A]);
      await controller.close();

      final lines = await linesFuture;

      expect(lines, isNotEmpty);
      expect(lines.join('\n'), contains('�'));
    });
  });
}
