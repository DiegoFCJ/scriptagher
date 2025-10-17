import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/custom_logger.dart';

import '../db/bot_database.dart';
import '../models/bot.dart';

class ExecutionService {
  ExecutionService(this._botDatabase);

  final BotDatabase _botDatabase;
  final CustomLogger _logger = CustomLogger();

  Future<Response> streamExecution(
      Request request, String language, String botName) async {
    final Bot? bot = await _botDatabase.findBotByName(language, botName);

    if (bot == null || bot.startCommand.trim().isEmpty) {
      final errorMessage =
          'Bot $language/$botName not found or missing start command.';
      _logger.error(LOGS.EXECUTION_SERVICE, errorMessage);
      return Response.notFound(jsonEncode({'error': errorMessage}));
    }

    final controller = StreamController<List<int>>();
    final logSink = await _prepareLogSink(bot);
    Process? process;
    var closed = false;
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;

    void addEvent(Map<String, dynamic> event) {
      final payload = 'data: ${jsonEncode(event)}\n\n';
      controller.add(utf8.encode(payload));
    }

    Future<void> closeResources() async {
      if (closed) {
        return;
      }
      closed = true;
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      try {
        await logSink.flush();
      } finally {
        await logSink.close();
      }
      await controller.close();
    }

    Future(() async {
      try {
        addEvent({
          'type': 'status',
          'message': 'starting',
        });

        process = await Process.start(
          '/bin/sh',
          ['-c', bot.startCommand],
          workingDirectory: _resolveWorkingDirectory(bot),
          runInShell: false,
        );

        _logger.info(LOGS.EXECUTION_SERVICE,
            'Started execution for ${bot.language}/${bot.botName}.');

        stdoutSub = process!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          _handleLine(logSink, line,
              isError: false, emitter: (event) => addEvent(event));
        });

        stderrSub = process!.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          _handleLine(logSink, line,
              isError: true, emitter: (event) => addEvent(event));
        });

        final exitCode = await process!.exitCode;

        addEvent({
          'type': 'status',
          'message': 'finished',
          'code': exitCode,
        });

        logSink.writeln('[status] exit code: $exitCode');
        await closeResources();
      } catch (e, stack) {
        _logger.error(LOGS.EXECUTION_SERVICE,
            'Execution failed for ${bot.language}/${bot.botName}: $e');
        logSink.writeln('[error] $e');
        logSink.writeln(stack.toString());
        addEvent({
          'type': 'error',
          'message': e.toString(),
        });
        await closeResources();
      }
    });

    controller.onCancel = () async {
      _logger.info(LOGS.EXECUTION_SERVICE,
          'Stream cancelled for ${bot.language}/${bot.botName}.');
      process?.kill();
      await closeResources();
    };

    return Response.ok(
      controller.stream,
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  Future<IOSink> _prepareLogSink(Bot bot) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final directory =
        Directory('logs/executions/${bot.language}/${bot.botName}');
    await directory.create(recursive: true);
    final file = File('${directory.path}/run_$timestamp.log');
    return file.openWrite(mode: FileMode.append);
  }

  void _handleLine(IOSink logSink, String line,
      {required bool isError,
      required void Function(Map<String, dynamic> event) emitter}) {
    final entryType = isError ? 'stderr' : 'stdout';
    logSink.writeln('[$entryType] $line');
    emitter({
      'type': entryType,
      'message': line,
    });
  }

  String? _resolveWorkingDirectory(Bot bot) {
    try {
      final sourceFile = File(bot.sourcePath);
      if (sourceFile.existsSync()) {
        return sourceFile.parent.path;
      }

      final sourceDir = Directory(bot.sourcePath);
      if (sourceDir.existsSync()) {
        return sourceDir.path;
      }
    } catch (_) {
      // Ignored: fallback to default working directory.
    }
    return null;
  }
}
