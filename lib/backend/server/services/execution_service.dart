import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
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
  final Map<String, _ManagedProcess> _runningProcesses = {};
  final Map<String, _CompletedProcess> _completedProcesses = {};
  final List<String> _completedOrder = [];

  Future<Response> startBot(
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

    ExecutionLogSession session;
    try {
      session = await _logManager.startSession(bot);
    } catch (e) {
      final message =
          'Unable to prepare log session for ${bot.language}/${bot.botName}: $e';
      _logger.error(LOGS.EXECUTION_SERVICE, message,
          metadata: {'language': language, 'botName': botName});
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'log_session_failed',
          'message': message,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final process = await _spawnProcess(bot);

      final stdoutSub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _handleLine(session, line,
            isError: false, emitter: (event) {});
      }, onError: (Object error, StackTrace stackTrace) {
        _logger.error(
          LOGS.EXECUTION_SERVICE,
          'Stdout stream error for ${bot.language}/${bot.botName}: $error',
          metadata: session.metadata.toLogMetadata(),
        );
        session.logSink.writeln('[stdout-error] $error');
        session.logSink.writeln(stackTrace.toString());
      });

      final stderrSub = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _handleLine(session, line,
            isError: true, emitter: (event) {});
      }, onError: (Object error, StackTrace stackTrace) {
        _logger.error(
          LOGS.EXECUTION_SERVICE,
          'Stderr stream error for ${bot.language}/${bot.botName}: $error',
          metadata: session.metadata.toLogMetadata(entryType: 'stderr'),
        );
        session.logSink.writeln('[stderr-error] $error');
        session.logSink.writeln(stackTrace.toString());
      });

      final processId = _generateProcessId(bot, process.pid);
      final managedProcess = _ManagedProcess(
        id: processId,
        bot: bot,
        process: process,
        session: session,
        stdoutSub: stdoutSub,
        stderrSub: stderrSub,
        startedAt: DateTime.now().toUtc(),
      );
      _runningProcesses[processId] = managedProcess;

      _logger.info(
        LOGS.EXECUTION_SERVICE,
        'Started execution for ${bot.language}/${bot.botName} (pid: ${process.pid}).',
        metadata: session.metadata.toLogMetadata(),
      );
      session.logSink
          .writeln('[status] process started (pid: ${process.pid})');

      process.exitCode.then((exitCode) {
        _handleManagedExit(managedProcess, exitCode);
      }).catchError((error, stackTrace) async {
        _logger.error(
          LOGS.EXECUTION_SERVICE,
          'Failed to await exit code for ${bot.language}/${bot.botName}: $error',
          metadata: session.metadata.toLogMetadata(),
        );
        await _handleManagedExit(managedProcess, -1,
            errorMessage: error.toString());
      });

      return Response.ok(
        jsonEncode({
          'status': 'started',
          'processId': processId,
          'pid': process.pid,
          'runId': session.metadata.runId,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      _logger.error(
        LOGS.EXECUTION_SERVICE,
        'Execution failed for ${bot.language}/${bot.botName}: $e',
        metadata: session.metadata.toLogMetadata(),
      );
      session.logSink.writeln('[error] $e');
      session.logSink.writeln(stack.toString());
      await _logManager.finalizeSession(session,
          exitCode: -1, errorMessage: e.toString());
      await session.dispose();
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'start_failed',
          'message': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

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

        process = await _spawnProcess(bot);

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
      headers: const <String, String>{
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
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

  List<List<String>> _buildCommandCandidates(Bot bot) {
    final trimmedCommand = bot.startCommand.trim();
    if (trimmedCommand.isEmpty) {
      throw StateError('Start command is empty for ${bot.botName}.');
    }

    final tokens = _splitCommand(trimmedCommand).toList();
    if (tokens.isEmpty) {
      throw StateError('Unable to parse start command for ${bot.botName}.');
    }

    final language = bot.language.toLowerCase();
    final candidates = <List<String>>[];

    bool addIfUnique(List<String> values) {
      final exists = candidates.any((candidate) =>
          candidate.length == values.length &&
          const IterableEquality<String>().equals(candidate, values));
      if (!exists) {
        candidates.add(values);
        return true;
      }
      return false;
    }

    switch (language) {
      case 'python':
      case 'py':
        if (_looksLikePythonInterpreter(tokens.first)) {
          addIfUnique(tokens);
        } else {
          addIfUnique(['python3', ...tokens]);
          addIfUnique(['python', ...tokens]);
        }
        break;
      case 'node':
      case 'javascript':
        if (_looksLikeNodeInterpreter(tokens.first)) {
          addIfUnique(tokens);
        } else {
          addIfUnique(['node', ...tokens]);
          addIfUnique(['nodejs', ...tokens]);
        }
        break;
      case 'bash':
      case 'shell':
        if (_looksLikeShell(tokens.first)) {
          addIfUnique(tokens);
        } else {
          addIfUnique(['/bin/bash', ...tokens]);
          addIfUnique(['/bin/sh', ...tokens]);
        }
        break;
      default:
        addIfUnique(tokens);
        break;
    }

    if (candidates.isEmpty) {
      candidates.add(tokens);
    }

    return candidates;
  }

  Future<Process> _spawnProcess(Bot bot) async {
    final workingDirectory = _resolveWorkingDirectory(bot);
    final candidates = _buildCommandCandidates(bot);
    ProcessException? lastError;

    for (final candidate in candidates) {
      final executable = candidate.first;
      final args = candidate.skip(1).toList();
      try {
        return await Process.start(
          executable,
          args,
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
      candidates.first.first,
      candidates.first.skip(1).toList(),
      'Unable to start process for ${bot.botName}.',
    );
  }

  Iterable<String> _splitCommand(String command) sync* {
    final buffer = StringBuffer();
    var inSingleQuote = false;
    var inDoubleQuote = false;
    var escaping = false;

    String? flush() {
      if (buffer.isNotEmpty) {
        final token = buffer.toString();
        buffer.clear();
        return token;
      }
      return null;
    }

    for (final rune in command.runes) {
      final char = String.fromCharCode(rune);
      if (escaping) {
        buffer.write(char);
        escaping = false;
        continue;
      }

      if (char == '\\') {
        escaping = true;
        continue;
      }

      if (char == '\'' && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        continue;
      }

      if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        continue;
      }

      if (char.trim().isEmpty && !inSingleQuote && !inDoubleQuote) {
        final token = flush();
        if (token != null) {
          yield token;
        }
        continue;
      }

      buffer.write(char);
    }

    final token = flush();
    if (token != null) {
      yield token;
    }
  }

  bool _looksLikePythonInterpreter(String value) {
    final normalized = value.toLowerCase();
    return normalized == 'python' || normalized == 'python3' ||
        normalized.startsWith('python3.');
  }

  bool _looksLikeNodeInterpreter(String value) {
    final normalized = value.toLowerCase();
    return normalized == 'node' || normalized == 'nodejs';
  }

  bool _looksLikeShell(String value) {
    final normalized = value.toLowerCase();
    return normalized == 'bash' ||
        normalized == '/bin/bash' ||
        normalized == 'sh' ||
        normalized == '/bin/sh';
  }

  String _generateProcessId(Bot bot, int pid) {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return '${bot.language}-${bot.botName}-$pid-$timestamp';
  }

  Future<void> _handleManagedExit(_ManagedProcess managed, int exitCode,
      {String? errorMessage}) async {
    if (!_runningProcesses.containsKey(managed.id)) {
      return;
    }

    try {
      managed.session.logSink.writeln('[status] exit code: $exitCode');
      await _logManager.finalizeSession(managed.session,
          exitCode: exitCode, errorMessage: errorMessage);
      _logger.info(
        LOGS.EXECUTION_SERVICE,
        'Execution finished for ${managed.bot.language}/${managed.bot.botName} with exit code $exitCode.',
        metadata: managed.session.metadata.toLogMetadata(),
      );
    } catch (e, stack) {
      _logger.error(
        LOGS.EXECUTION_SERVICE,
        'Failed to finalize session for ${managed.bot.language}/${managed.bot.botName}: $e',
        metadata: managed.session.metadata.toLogMetadata(),
      );
      managed.session.logSink.writeln('[finalize-error] $e');
      managed.session.logSink.writeln(stack.toString());
    } finally {
      await managed.stdoutSub.cancel();
      await managed.stderrSub.cancel();
      await managed.session.dispose();
      _runningProcesses.remove(managed.id);
      _storeCompletedProcess(managed, exitCode);
    }
  }

  Future<Response> stopBot(
      Request request, String language, String botName) async {
    return _handleSignal(request, language, botName,
        signal: ProcessSignal.sigterm, action: 'stop');
  }

  Future<Response> killBot(
      Request request, String language, String botName) async {
    final signal = _supportsSigKill ? ProcessSignal.sigkill : ProcessSignal.sigterm;
    return _handleSignal(request, language, botName,
        signal: signal, action: 'kill');
  }

  Future<Response> _handleSignal(Request request, String language, String botName,
      {required ProcessSignal signal, required String action}) async {
    final processId = _extractProcessId(request);

    _logger.info(
      LOGS.EXECUTION_SERVICE,
      'Received $action request for $language/$botName (processId: ${processId ?? 'auto'}).',
      metadata: {'language': language, 'botName': botName, if (processId != null) 'processId': processId},
    );

    _ManagedProcess? managed;
    try {
      managed = _resolveManagedProcess(language, botName, processId: processId);
    } on _AmbiguousProcessException catch (e) {
      return Response(400,
          body: jsonEncode({
            'error': 'multiple_processes',
            'message':
                'Più processi attivi per $language/$botName. Specifica processId.',
            'processes': e.processIds,
          }),
          headers: {'Content-Type': 'application/json'});
    }

    if (managed == null) {
      if (processId != null) {
        final completed = _completedProcesses[processId];
        if (completed != null) {
          return Response.ok(
            jsonEncode({
              'status': 'not_running',
              'processId': processId,
              'exitCode': completed.exitCode,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      return Response.notFound(
        jsonEncode({
          'error': 'process_not_found',
          'message': processId == null
              ? 'Nessun processo attivo per $language/$botName.'
              : 'Processo $processId non trovato per $language/$botName.',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final success = managed.process.kill(signal);

    final exitCode = await _awaitExitCode(managed);

    if (!success && exitCode == null) {
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'signal_failed',
          'message':
              'Impossibile inviare il segnale $signal al processo ${managed.id}.',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({
        'status': exitCode != null ? 'terminated' : 'signal_sent',
        'processId': managed.id,
        'exitCode': exitCode,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  _ManagedProcess? _resolveManagedProcess(String language, String botName,
      {String? processId}) {
    if (processId != null) {
      return _runningProcesses[processId];
    }

    final matches = _runningProcesses.values
        .where((proc) =>
            proc.bot.language == language && proc.bot.botName == botName)
        .toList();

    if (matches.length == 1) {
      return matches.first;
    }

    if (matches.isEmpty) {
      return null;
    }

    throw _AmbiguousProcessException(matches.map((p) => p.id).toList());
  }

  String? _extractProcessId(Request request) {
    final qp = request.url.queryParameters;
    return qp['processId'] ?? qp['process_id'];
  }

  Future<int?> _awaitExitCode(_ManagedProcess managed) async {
    try {
      return await managed.process.exitCode
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void _storeCompletedProcess(_ManagedProcess managed, int exitCode) {
    _completedProcesses[managed.id] = _CompletedProcess(
      bot: managed.bot,
      exitCode: exitCode,
      finishedAt: DateTime.now().toUtc(),
    );
    _completedOrder.add(managed.id);

    const maxCompleted = 50;
    while (_completedOrder.length > maxCompleted) {
      final oldest = _completedOrder.removeAt(0);
      _completedProcesses.remove(oldest);
    }
  }

  bool get _supportsSigKill => !Platform.isWindows;
}

class _ManagedProcess {
  _ManagedProcess({
    required this.id,
    required this.bot,
    required this.process,
    required this.session,
    required this.stdoutSub,
    required this.stderrSub,
    required this.startedAt,
  });

  final String id;
  final Bot bot;
  final Process process;
  final ExecutionLogSession session;
  final StreamSubscription<String> stdoutSub;
  final StreamSubscription<String> stderrSub;
  final DateTime startedAt;
}

class _CompletedProcess {
  _CompletedProcess({
    required this.bot,
    required this.exitCode,
    required this.finishedAt,
  });

  final Bot bot;
  final int exitCode;
  final DateTime finishedAt;
}

class _AmbiguousProcessException implements Exception {
  _AmbiguousProcessException(this.processIds);

  final List<String> processIds;

  @override
  String toString() =>
      'Multiple processes match the criteria: ${processIds.join(', ')}';
}
