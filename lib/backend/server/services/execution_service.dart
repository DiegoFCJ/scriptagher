import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/custom_logger.dart';

import '../db/bot_database.dart';
import '../models/bot.dart';
import 'execution_log_service.dart';

class ExecutionService {
  ExecutionService(this._botDatabase, this._logManager);

  final BotDatabase _botDatabase;
  final ExecutionLogManager _logManager;
  final CustomLogger _logger = CustomLogger();
  final Map<int, _PendingProcess> _pendingProcesses = {};

  Future<Response> startBot(
      Request request, String language, String botName) async {
    final Bot? bot = await _botDatabase.findBotByName(language, botName);

    if (bot == null) {
      final errorMessage =
          'Bot $language/$botName not found. Unable to start execution.';
      _logger.error(LOGS.EXECUTION_SERVICE, errorMessage,
          metadata: {'language': language, 'botName': botName});
      return Response.notFound(jsonEncode({'error': errorMessage}));
    }

    final runner = _resolveRunnerCommand(bot);
    if (runner == null) {
      final message =
          'Bot ${bot.language}/${bot.botName} missing start command or unsupported language.';
      _logger.error(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      return Response.internalServerError(
        body: jsonEncode({'error': message}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final process = await _startProcess(bot, runner);
      final pending = _PendingProcess(bot: bot, process: process);
      _pendingProcesses[process.pid] = pending;
      process.exitCode.then((_) {
        _pendingProcesses.remove(process.pid);
      });

      _logger.info(
        LOGS.EXECUTION_SERVICE,
        'Started process ${process.pid} for ${bot.language}/${bot.botName}.',
        metadata: {'language': language, 'botName': botName, 'pid': process.pid},
      );

      return Response.ok(
        jsonEncode({
          'pid': process.pid,
          'status': 'started',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      final message =
          'Failed to start ${bot.language}/${bot.botName}: ${e.toString()}';
      _logger.error(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      return Response.internalServerError(
        body: jsonEncode({'error': message}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> streamExecution(
      Request request, String language, String botName) async {
    final Bot? botFromDb = await _botDatabase.findBotByName(language, botName);

    if (botFromDb == null) {
      final errorMessage = 'Bot $language/$botName not found.';
      _logger.error(LOGS.EXECUTION_SERVICE, errorMessage,
          metadata: {'language': language, 'botName': botName});
      return Response.notFound(jsonEncode({'error': errorMessage}));
    }

    Bot bot = botFromDb;

    final controller = StreamController<List<int>>();
    Process? process;
    final pidParam = request.requestedUri.queryParameters['pid'];
    if (pidParam != null) {
      final pid = int.tryParse(pidParam);
      if (pid != null) {
        final pending = _pendingProcesses.remove(pid);
        if (pending != null) {
          process = pending.process;
          bot = pending.bot;
        }
      }
    }

    final runner = _resolveRunnerCommand(bot);
    if (runner == null) {
      final message =
          'Bot ${bot.language}/${bot.botName} missing start command or unsupported language.';
      _logger.error(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      await controller.close();
      return Response.internalServerError(
        body: jsonEncode({'error': message}),
        headers: {'Content-Type': 'application/json'},
      );
    }

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

        process ??= await _startProcess(bot, runner);

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

  Future<Process> _startProcess(Bot bot, _RunnerCommand runner) async {
    final workingDirectory = _resolveWorkingDirectory(bot);
    ProcessException? lastError;
    for (final executable in runner.executables) {
      try {
        return await Process.start(
          executable,
          runner.arguments,
          workingDirectory: workingDirectory,
          runInShell: false,
        );
      } on ProcessException catch (error) {
        lastError = error;
        continue;
      }
    }
    if (lastError != null) {
      throw lastError;
    }
    throw ProcessException(
      runner.executables.first,
      runner.arguments,
      'Unable to start runner for ${bot.language}/${bot.botName}',
    );
  }

  _RunnerCommand? _resolveRunnerCommand(Bot bot) {
    final language = bot.language.toLowerCase().trim();
    final command = bot.startCommand.trim();
    if (command.isEmpty) {
      return null;
    }

    final args = _splitArguments(command);
    if (language.contains('python')) {
      if (args.isEmpty) {
        return null;
      }
      if (args.isNotEmpty &&
          (args.first.toLowerCase() == 'python' ||
              args.first.toLowerCase() == 'python3')) {
        args.removeAt(0);
      }
      if (args.isEmpty) {
        return null;
      }
      return _RunnerCommand(['python3', 'python'], args);
    }

    if (language.contains('node') || language.contains('javascript')) {
      if (args.isEmpty) {
        return null;
      }
      if (args.isNotEmpty && args.first.toLowerCase() == 'node') {
        args.removeAt(0);
      }
      if (args.isEmpty) {
        return null;
      }
      return _RunnerCommand(['node'], args);
    }

    if (language.contains('bash') ||
        language.contains('shell') ||
        language.contains('sh')) {
      if (args.isNotEmpty &&
          (args.first.toLowerCase() == 'bash' ||
              args.first.toLowerCase() == 'sh')) {
        args.removeAt(0);
      }
      if (args.isEmpty) {
        return null;
      }
      return _RunnerCommand(['bash', 'sh'], args);
    }

    return _RunnerCommand(['/bin/sh'], ['-c', command]);
  }

  List<String> _splitArguments(String command) {
    final matches = RegExp(r'''(?:[^\s'"]+|'[^']*'|"[^"]*")''')
        .allMatches(command)
        .map((match) => match.group(0)!)
        .map(_stripEnclosingQuotes)
        .where((element) => element.isNotEmpty)
        .toList();
    return matches;
  }

  String _stripEnclosingQuotes(String value) {
    if (value.length >= 2) {
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
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

class _RunnerCommand {
  _RunnerCommand(this.executables, List<String> args)
      : arguments = List<String>.from(args);

  final List<String> executables;
  final List<String> arguments;
}

class _PendingProcess {
  _PendingProcess({required this.bot, required this.process});

  final Bot bot;
  final Process process;
}
