import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:scriptagher/backend/server/services/execution_service.dart';

void main() {
  group('ExecutionService.lossyUtf8LineStream', () {
    test('decodes invalid UTF-8 bytes without throwing', () async {
      final controller = StreamController<List<int>>();
      final lines = <String>[];
      final errors = <Object>[];
      final completer = Completer<void>();

      ExecutionService.lossyUtf8LineStream(controller.stream).listen(
        lines.add,
        onError: errors.add,
        onDone: () => completer.complete(),
      );

      controller
        ..add(<int>[0x61, 0x62])
        ..add(<int>[0xff, 0x63, 0x0a])
        ..add(<int>[0x64, 0x65, 0x0a])
        ..close();

      await completer.future;

      expect(errors, isEmpty);
      expect(lines, equals(<String>['ab�c', 'de']));
    });
  });
}
