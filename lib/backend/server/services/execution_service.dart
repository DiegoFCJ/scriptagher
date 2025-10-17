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
  final Map<String, _ProcessHandle> _activeProcesses = {};
  final Map<String, int> _lastExitCodes = {};

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

    final processKey = _processKey(bot.language, bot.botName);

    if (_activeProcesses.containsKey(processKey)) {
      final message =
          'Execution already running for ${bot.language}/${bot.botName}.';
      _logger.warn(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      return Response(409,
          body: jsonEncode({'error': message}),
          headers: {'Content-Type': 'application/json'});
    }

    _lastExitCodes.remove(processKey);

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
    _ProcessHandle? processHandle;
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

        processHandle = _registerProcess(processKey, process!);

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

        final exitCode = await processHandle!.exitCode;

        addEvent({
          'type': 'status',
          'message': 'finished',
          'code': exitCode,
        });

        session.logSink.writeln('[status] exit code: $exitCode');
        await finalize(exitCode);
        _lastExitCodes[processKey] = exitCode;
        _activeProcesses.remove(processKey);
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
        _lastExitCodes[processKey] = -1;
        _activeProcesses.remove(processKey);
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

  ProcessControlResult stopProcess(String language, String botName) {
    return _sendSignal(language, botName, ProcessSignal.sigterm,
        statusWhenSuccess: ProcessControlStatus.signalSent,
        failureMessage: 'Impossibile inviare il segnale di terminazione.');
  }

  ProcessControlResult killProcess(String language, String botName) {
    final ProcessSignal? killSignal = Platform.isWindows
        ? null
        : ProcessSignal.sigkill;
    return _sendSignal(language, botName, killSignal,
        statusWhenSuccess: ProcessControlStatus.signalSent,
        failureMessage: 'Impossibile forzare la terminazione del processo.');
  }

  Future<int?> getExitCode(String language, String botName,
      {Duration? waitFor}) async {
    final key = _processKey(language, botName);
    final handle = _activeProcesses[key];
    if (handle != null) {
      if (handle.lastExitCode != null) {
        return handle.lastExitCode;
      }
      if (waitFor != null) {
        try {
          final code = await handle.exitCode.timeout(waitFor);
          return code;
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    return _lastExitCodes[key];
  }

  ProcessControlResult _sendSignal(
    String language,
    String botName,
    ProcessSignal? signal, {
    required ProcessControlStatus statusWhenSuccess,
    required String failureMessage,
  }) {
    final key = _processKey(language, botName);
    final handle = _activeProcesses[key];

    if (handle == null) {
      return ProcessControlResult(
        status: ProcessControlStatus.notRunning,
        wasRunning: false,
        signalSent: false,
        exitCode: _lastExitCodes[key],
        message: 'Nessuna esecuzione attiva per $language/$botName.',
      );
    }

    final bool sent;
    try {
      if (signal == null) {
        sent = handle.kill();
      } else {
        sent = handle.sendSignal(signal);
      }
    } catch (e) {
      return ProcessControlResult(
        status: ProcessControlStatus.signalFailed,
        wasRunning: true,
        signalSent: false,
        exitCode: handle.lastExitCode,
        message: '$failureMessage Errore: $e',
      );
    }

    if (!sent) {
      return ProcessControlResult(
        status: ProcessControlStatus.signalFailed,
        wasRunning: true,
        signalSent: false,
        exitCode: handle.lastExitCode,
        message: failureMessage,
      );
    }

    return ProcessControlResult(
      status: statusWhenSuccess,
      wasRunning: true,
      signalSent: true,
      exitCode: handle.lastExitCode,
    );
  }

  _ProcessHandle _registerProcess(String key, Process process) {
    final handle = _ProcessHandle(process, onExit: (exitCode) {
      _lastExitCodes[key] = exitCode;
      _activeProcesses.remove(key);
    });
    _activeProcesses[key] = handle;
    return handle;
  }

  String _processKey(String language, String botName) => '$language/$botName';
}

enum ProcessControlStatus { notRunning, signalSent, signalFailed }

class ProcessControlResult {
  ProcessControlResult({
    required this.status,
    required this.wasRunning,
    required this.signalSent,
    this.exitCode,
    this.message,
  });

  final ProcessControlStatus status;
  final bool wasRunning;
  final bool signalSent;
  final int? exitCode;
  final String? message;

  String get statusLabel {
    switch (status) {
      case ProcessControlStatus.notRunning:
        return 'not_running';
      case ProcessControlStatus.signalSent:
        return 'signal_sent';
      case ProcessControlStatus.signalFailed:
        return 'signal_failed';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'status': statusLabel,
      'was_running': wasRunning,
      'signal_sent': signalSent,
      'exit_code': exitCode,
      if (message != null) 'message': message,
    };
  }
}

class _ProcessHandle {
  _ProcessHandle(this.process, {void Function(int exitCode)? onExit})
      : _exitCodeCompleter = Completer<int>() {
    process.exitCode.then((value) {
      lastExitCode = value;
      if (!_exitCodeCompleter.isCompleted) {
        _exitCodeCompleter.complete(value);
      }
      onExit?.call(value);
    }).catchError((error, stackTrace) {
      if (!_exitCodeCompleter.isCompleted) {
        _exitCodeCompleter.completeError(error, stackTrace);
      }
    });
  }

  final Process process;
  final Completer<int> _exitCodeCompleter;
  int? lastExitCode;

  Future<int> get exitCode => _exitCodeCompleter.future;

  bool sendSignal(ProcessSignal signal) {
    try {
      return process.kill(signal);
    } on UnsupportedError {
      if (signal == ProcessSignal.sigkill) {
        return process.kill();
      }
      rethrow;
    }
  }

  bool kill() {
    if (Platform.isWindows) {
      return process.kill();
    }
    return sendSignal(ProcessSignal.sigkill);
  }
}
