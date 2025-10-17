import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/custom_logger.dart';

import '../db/bot_database.dart';
import '../models/bot.dart';
import 'execution_log_service.dart';

class _ExecutionHandle {
  _ExecutionHandle(this.process);

  Process? process;
  int? exitCode;

  bool get isRunning => process != null;
}

class ExecutionSignalResult {
  ExecutionSignalResult({
    required this.signal,
    required this.wasRunning,
    required this.signalDelivered,
    required this.isRunning,
    required this.exitCode,
  });

  final ProcessSignal signal;
  final bool wasRunning;
  final bool signalDelivered;
  final bool isRunning;
  final int? exitCode;

  String get signalName {
    if (signal == ProcessSignal.sigterm) {
      return 'SIGTERM';
    }
    if (signal == ProcessSignal.sigkill) {
      return 'SIGKILL';
    }
    return signal.toString();
  }

  Map<String, dynamic> toJson() {
    return {
      'signal': signalName,
      'was_running': wasRunning,
      'signal_delivered': signalDelivered,
      'is_running': isRunning,
      'exit_code': exitCode,
    };
  }
}

class ExecutionService {
  ExecutionService(this._botDatabase, this._logManager);

  final BotDatabase _botDatabase;
  final ExecutionLogManager _logManager;
  final CustomLogger _logger = CustomLogger();
  final Map<String, _ExecutionHandle> _executionHandles = {};

  Future<Response> streamExecution(
      Request request, String language, String botName) async {
    final Bot? bot = await _botDatabase.findBotByName(language, botName);

    if (bot == null || bot.startCommand.trim().isEmpty) {
      final errorMessage =
          'Bot $language/$botName not found or missing start command.';
      _logger.error(LOGS.EXECUTION_SERVICE, errorMessage,
          metadata: {'language': language, 'botName': botName});
      return Response.notFound(jsonEncode({'error': errorMessage}));
    }

    final controller = StreamController<List<int>>();
    late final ExecutionLogSession session;
    try {
      session = await _logManager.startSession(bot);
    } catch (e) {
      final message =
          'Unable to prepare log session for ${bot.language}/${bot.botName}: $e';
      _logger.error(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      controller.add(utf8.encode(
          'data: ${jsonEncode({'type': 'error', 'message': message})}\n\n'));
      await controller.close();
      return Response.internalServerError(
        body: jsonEncode({'error': message}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    Process? process;
    final executionKey = _processKey(bot.language, bot.botName);
    var closed = false;
    var finalized = false;
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;

    void addEvent(Map<String, dynamic> event) {
      final payload = 'data: ${jsonEncode(event)}\n\n';
      controller.add(utf8.encode(payload));
    }

    Future<void> finalize(int exitCode, {String? errorMessage}) async {
      if (finalized) {
        return;
      }
      finalized = true;
      await _logManager.finalizeSession(session,
          exitCode: exitCode, errorMessage: errorMessage);
      _logger.info(
        LOGS.EXECUTION_SERVICE,
        'Execution finished for ${bot.language}/${bot.botName} with exit code $exitCode.',
        metadata: session.metadata.toLogMetadata(),
      );
    }

    Future<void> closeResources() async {
      if (closed) {
        return;
      }
      closed = true;
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      try {
        await session.dispose();
      } finally {
        await controller.close();
      }
    }

    Future(() async {
      try {
        addEvent({
          'type': 'status',
          'message': 'starting',
        });

        _logger.info(
          LOGS.EXECUTION_SERVICE,
          'Started execution for ${bot.language}/${bot.botName}.',
          metadata: session.metadata.toLogMetadata(),
        );

        process = await Process.start(
          '/bin/sh',
          ['-c', bot.startCommand],
          workingDirectory: _resolveWorkingDirectory(bot),
          runInShell: false,
        );

        final handle = _ExecutionHandle(process);
        _executionHandles[executionKey] = handle;
        process.exitCode.then((value) {
          handle
            ..exitCode = value
            ..process = null;
        });

        stdoutSub = process!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          _handleLine(session, line,
              isError: false, emitter: (event) => addEvent(event));
        });

        stderrSub = process!.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          _handleLine(session, line,
              isError: true, emitter: (event) => addEvent(event));
        });

        final exitCode = await process!.exitCode;
        final handle = _executionHandles[executionKey];
        if (handle != null) {
          handle
            ..exitCode = exitCode
            ..process = null;
        }

        addEvent({
          'type': 'status',
          'message': 'finished',
          'code': exitCode,
        });

        session.logSink.writeln('[status] exit code: $exitCode');
        await finalize(exitCode);
        await closeResources();
      } catch (e, stack) {
        _logger.error(
          LOGS.EXECUTION_SERVICE,
          'Execution failed for ${bot.language}/${bot.botName}: $e',
          metadata: session.metadata.toLogMetadata(),
        );
        session.logSink.writeln('[error] $e');
        session.logSink.writeln(stack.toString());
        addEvent({
          'type': 'error',
          'message': e.toString(),
        });
        final handle = _executionHandles[executionKey];
        if (handle != null) {
          handle
            ..exitCode = -1
            ..process = null;
        }
        await finalize(-1, errorMessage: e.toString());
        await closeResources();
      }
    });

    controller.onCancel = () async {
      _logger.info(
        LOGS.EXECUTION_SERVICE,
        'Stream cancelled for ${bot.language}/${bot.botName}.',
        metadata: session.metadata.toLogMetadata(),
      );
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

  ExecutionSignalResult? stopProcess(String language, String botName) {
    return _sendSignal(language, botName, ProcessSignal.sigterm);
  }

  ExecutionSignalResult? killProcess(String language, String botName) {
    return _sendSignal(language, botName, ProcessSignal.sigkill);
  }

  int? getExitCode(String language, String botName) {
    final handle = _executionHandles[_processKey(language, botName)];
    return handle?.exitCode;
  }

  bool isRunning(String language, String botName) {
    final handle = _executionHandles[_processKey(language, botName)];
    return handle?.isRunning ?? false;
  }

  ExecutionSignalResult? _sendSignal(
      String language, String botName, ProcessSignal signal) {
    final key = _processKey(language, botName);
    final handle = _executionHandles[key];
    if (handle == null) {
      return null;
    }

    final wasRunning = handle.isRunning;
    final bool signalDelivered;
    if (handle.process != null) {
      signalDelivered = handle.process!.kill(signal);
    } else {
      signalDelivered = false;
    }

    return ExecutionSignalResult(
      signal: signal,
      wasRunning: wasRunning,
      signalDelivered: signalDelivered,
      isRunning: handle.isRunning,
      exitCode: handle.exitCode,
    );
  }

  String _processKey(String language, String botName) => '$language/$botName';

  Future<Response> listLogs(
      Request request, String language, String botName) async {
    try {
      final logs = await _logManager.listLogs(language, botName);
      final payload = logs.map((log) => log.toJson()).toList();
      return Response.ok(jsonEncode(payload),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      _logger.error(
        LOGS.EXECUTION_SERVICE,
        'Failed to list logs for $language/$botName: $e',
        metadata: {'language': language, 'botName': botName},
      );
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'Unable to read logs',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> downloadLog(Request request, String language,
      String botName, String runId) async {
    try {
      final metadata =
          await _logManager.loadMetadata(language, botName, runId);
      if (metadata == null) {
        return Response.notFound(
          jsonEncode({'error': 'Log non trovato'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      final logFile =
          await _logManager.openLogFile(language, botName, metadata.logFileName);
      if (logFile == null) {
        return Response.notFound(
          jsonEncode({'error': 'File di log non disponibile'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        logFile.openRead(),
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Content-Disposition':
              'attachment; filename="${metadata.logFileName}"',
          'Access-Control-Expose-Headers': 'Content-Disposition',
        },
      );
    } catch (e) {
      _logger.error(
        LOGS.EXECUTION_SERVICE,
        'Failed to download log $runId for $language/$botName: $e',
        metadata: {'language': language, 'botName': botName, 'runId': runId},
      );
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'Unable to download log',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  void _handleLine(ExecutionLogSession session, String line,
      {required bool isError,
      required void Function(Map<String, dynamic> event) emitter}) {
    final entryType = isError ? 'stderr' : 'stdout';
    session.logSink.writeln('[$entryType] $line');
    emitter({
      'type': entryType,
      'message': line,
    });

    final metadata = session.metadata.toLogMetadata(entryType: entryType);
    if (isError) {
      _logger.error(LOGS.EXECUTION_SERVICE, line, metadata: metadata);
    } else {
      _logger.debug(LOGS.EXECUTION_SERVICE, line, metadata: metadata);
    }
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
