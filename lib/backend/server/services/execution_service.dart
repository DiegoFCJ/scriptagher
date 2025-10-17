import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/custom_logger.dart';

import '../db/bot_database.dart';
import '../models/bot.dart';
import 'execution_log_service.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';

class ExecutionService {
  ExecutionService(this._botDatabase, this._logManager);

  final BotDatabase _botDatabase;
  final ExecutionLogManager _logManager;
  final CustomLogger _logger = CustomLogger();
  final Map<String, _ExecutionHandle> _activeExecutions = {};

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

    final requiredPermissions = await _resolvePermissions(bot);
    final grantedPermissions = _parseGrantedPermissions(request);
    final missingPermissions = requiredPermissions
        .where((perm) => !grantedPermissions.contains(perm))
        .toList();

    if (missingPermissions.isNotEmpty) {
      final message =
          'Missing permissions for ${bot.language}/${bot.botName}: ${missingPermissions.join(', ')}';
      _logger.warn(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      return Response.forbidden(
        jsonEncode({
          'error': 'permissions_denied',
          'missing_permissions': missingPermissions,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final controller = StreamController<List<int>>();
    late final ExecutionLogSession session;
    final executionKey = _executionKey(bot.language, bot.botName);
    _ExecutionHandle? handle;
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

        final previousHandle = _activeExecutions[executionKey];
        if (previousHandle != null && previousHandle.isRunning) {
          _logger.warn(
            LOGS.EXECUTION_SERVICE,
            'Existing execution for ${bot.language}/${bot.botName} is still running. Overwriting handle.',
            metadata: session.metadata.toLogMetadata(),
          );
        }

        final newHandle = _ExecutionHandle(process!);
        _activeExecutions[executionKey] = newHandle;
        handle = newHandle;

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
        handle?.complete(exitCode);
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
        handle?.complete(-1);
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
      final currentHandle = _activeExecutions[executionKey];
      if (currentHandle != null &&
          identical(currentHandle, handle) &&
          currentHandle.isRunning) {
        currentHandle.sendSignal(ProcessSignal.sigterm);
      }
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

  Future<ExecutionControlResult> stopExecution(
      String language, String botName) async {
    return _sendSignal(language, botName, ProcessSignal.sigterm, 'stop');
  }

  Future<ExecutionControlResult> killExecution(
      String language, String botName) async {
    return _sendSignal(language, botName, ProcessSignal.sigkill, 'kill');
  }

  ExecutionStatus getExecutionStatus(String language, String botName) {
    final key = _executionKey(language, botName);
    final handle = _activeExecutions[key];
    if (handle == null) {
      return const ExecutionStatus(
        isRunning: false,
        exitCode: null,
      );
    }
    return ExecutionStatus(
      isRunning: handle.isRunning,
      exitCode: handle.exitCode,
    );
  }

  Future<List<String>> _resolvePermissions(Bot bot) async {
    if (bot.permissions.isNotEmpty) {
      return bot.permissions;
    }

    try {
      final manifest = await BotUtils.fetchBotDetails(bot.sourcePath,
          expectedSha256: bot.archiveSha256);
      final permissions = (manifest['permissions'] as List?)
              ?.whereType<String>()
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList() ??
          const <String>[];
      return permissions;
    } catch (e) {
      _logger.warn(
        LOGS.EXECUTION_SERVICE,
        'Unable to resolve permissions for ${bot.language}/${bot.botName}: $e',
        metadata: {'language': bot.language, 'botName': bot.botName},
      );
      return const <String>[];
    }
  }

  Set<String> _parseGrantedPermissions(Request request) {
    final values = <String>{};
    final multi = request.url.queryParametersAll['grantedPermissions'];
    if (multi != null) {
      for (final entry in multi) {
        values.addAll(_splitPermissions(entry));
      }
    } else {
      final single = request.url.queryParameters['grantedPermissions'];
      if (single != null) {
        values.addAll(_splitPermissions(single));
      }
    }
    return values;
  }

  Iterable<String> _splitPermissions(String raw) {
    return raw
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
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

  Future<ExecutionControlResult> _sendSignal(String language, String botName,
      ProcessSignal signal, String action) async {
    final key = _executionKey(language, botName);
    final handle = _activeExecutions[key];

    if (handle == null) {
      final message =
          'No execution handle found for $language/$botName to perform $action.';
      _logger.warn(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      return ExecutionControlResult(
        statusCode: 404,
        status: 'not_found',
        message: message,
      );
    }

    if (!handle.isRunning) {
      final exitCode = handle.exitCode;
      final message = exitCode == null
          ? 'Bot $language/$botName is not running.'
          : 'Bot $language/$botName already finished with exit code $exitCode.';
      return ExecutionControlResult(
        statusCode: 200,
        status: 'not_running',
        message: message,
        exitCode: exitCode,
      );
    }

    final sent = handle.sendSignal(signal);
    if (!sent) {
      final message =
          'Unable to send $action signal to $language/$botName process.';
      _logger.warn(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      return ExecutionControlResult(
        statusCode: 409,
        status: 'signal_failed',
        message: message,
        wasRunning: true,
      );
    }

    int? exitCode;
    var timedOut = false;
    try {
      exitCode = await handle.exitCodeFuture
          .timeout(const Duration(seconds: 5), onTimeout: () {
        timedOut = true;
        return null;
      });
    } catch (_) {
      // If the future completes with an error we log and continue without exit code.
      timedOut = true;
    }

    if (exitCode != null) {
      final message =
          'Execution for $language/$botName terminated with exit code $exitCode after $action signal.';
      _logger.info(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      return ExecutionControlResult(
        statusCode: 200,
        status: 'terminated',
        message: message,
        exitCode: exitCode,
        wasRunning: true,
        signalSent: true,
      );
    }

    final message =
        'Signal $action sent to $language/$botName, awaiting process termination.';
    _logger.info(LOGS.EXECUTION_SERVICE, message,
        metadata: {'language': language, 'botName': botName});
    return ExecutionControlResult(
      statusCode: 202,
      status: 'pending_exit',
      message: message,
      exitCode: handle.exitCode,
      wasRunning: true,
      signalSent: true,
      timedOut: timedOut,
    );
  }

  String _executionKey(String language, String botName) {
    return '${language.toLowerCase()}::${botName.toLowerCase()}';
  }
}

class ExecutionStatus {
  const ExecutionStatus({required this.isRunning, required this.exitCode});

  final bool isRunning;
  final int? exitCode;
}

class ExecutionControlResult {
  ExecutionControlResult({
    required this.statusCode,
    required this.status,
    required this.message,
    this.exitCode,
    this.wasRunning = false,
    this.signalSent = false,
    this.timedOut = false,
  });

  final int statusCode;
  final String status;
  final String message;
  final int? exitCode;
  final bool wasRunning;
  final bool signalSent;
  final bool timedOut;

  Map<String, dynamic> toJson({String? action}) {
    return {
      if (action != null) 'action': action,
      'status': status,
      'message': message,
      'exitCode': exitCode,
      'wasRunning': wasRunning,
      'signalSent': signalSent,
      'timedOut': timedOut,
    };
  }
}

class _ExecutionHandle {
  _ExecutionHandle(this._process);

  Process? _process;
  int? exitCode;
  final Completer<int> _exitCodeCompleter = Completer<int>();

  bool get isRunning => _process != null;

  Future<int> get exitCodeFuture => _exitCodeCompleter.future;

  bool sendSignal(ProcessSignal signal) {
    final process = _process;
    if (process == null) {
      return false;
    }
    return process.kill(signal);
  }

  void complete(int code) {
    exitCode = code;
    _process = null;
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }
}
