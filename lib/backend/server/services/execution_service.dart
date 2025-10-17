import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';

import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/logging/log_metadata.dart';

import '../models/bot.dart';

class ExecutionResult {
  ExecutionResult({
    required this.exitCode,
    required this.logFile,
    required this.metadata,
  });

  final int exitCode;
  final File logFile;
  final LogMetadata metadata;
}

class ExecutionService {
  ExecutionService({CustomLogger? logger}) : _logger = logger ?? CustomLogger();

  final CustomLogger _logger;

  /// Executes the provided [bot] by running its start command inside the bot
  /// directory.
  ///
  /// Every execution generates an isolated log file that captures stdout and
  /// stderr while also forwarding the messages to the application logger.
  Future<ExecutionResult> runBot(Bot bot) async {
    final identifier = bot.id?.toString() ?? bot.botName;
    final metadata = LogMetadata(botId: identifier, startTime: DateTime.now());
    final logFile = await _logger.createRunLogFile(metadata);
    final logSink = logFile.openWrite(mode: FileMode.append);

    Future<void> writeLine(String prefix, String line) async {
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      logSink.writeln('[$timestamp][$prefix] $line');
      await logSink.flush();
    }

    final botConfig = File(bot.sourcePath);
    final workingDirectory = botConfig.parent;

    if (!await workingDirectory.exists()) {
      final errorMessage =
          'Working directory not found: ${workingDirectory.path}';
      _logger.error(LOGS.EXECUTION_SERVICE, errorMessage, metadata: metadata);
      await writeLine('ERROR', errorMessage);
      await logSink.close();
      throw FileSystemException(errorMessage, workingDirectory.path);
    }

    _logger.info(LOGS.EXECUTION_SERVICE,
        'Starting execution of ${bot.botName} using "${bot.startCommand}"',
        metadata: metadata);
    await writeLine('INFO', 'Starting execution');

    try {
      final process = await Process.start(
        _shellExecutable,
        _shellArguments(bot.startCommand),
        workingDirectory: workingDirectory.path,
        runInShell: Platform.isWindows,
      );

      final stdoutFuture = _pipeStream(
        stream: process.stdout,
        onLog: (line) {
          _logger.info(LOGS.EXECUTION_SERVICE, 'STDOUT: $line',
              metadata: metadata);
        },
        onWrite: (line) => writeLine('STDOUT', line),
      );

      final stderrFuture = _pipeStream(
        stream: process.stderr,
        onLog: (line) {
          _logger.error(LOGS.EXECUTION_SERVICE, 'STDERR: $line',
              metadata: metadata);
        },
        onWrite: (line) => writeLine('STDERR', line),
      );

      final exitCode = await process.exitCode;
      await Future.wait([stdoutFuture, stderrFuture]);

      final completedMetadata = metadata.copyWith(
        exitCode: exitCode,
        endTime: DateTime.now(),
      );

      final summary = 'Execution completed with exit code $exitCode';
      _logger.info(LOGS.EXECUTION_SERVICE, summary, metadata: completedMetadata);
      await writeLine('INFO', summary);

      logSink.writeln(completedMetadata.buildCompletionSection());
      await logSink.close();

      return ExecutionResult(
        exitCode: exitCode,
        logFile: logFile,
        metadata: completedMetadata,
      );
    } catch (e) {
      final failureMetadata = metadata.copyWith(endTime: DateTime.now());
      final errorMessage = 'Failed to execute bot ${bot.botName}: $e';
      _logger.error(LOGS.EXECUTION_SERVICE, errorMessage,
          metadata: failureMetadata);
      await writeLine('ERROR', errorMessage);
      await logSink.close();
      rethrow;
    }
  }

  static String get _shellExecutable => Platform.isWindows ? 'cmd' : '/bin/sh';

  static List<String> _shellArguments(String command) {
    return Platform.isWindows ? ['/c', command] : ['-c', command];
  }

  static Future<void> _pipeStream({
    required Stream<List<int>> stream,
    required void Function(String line) onLog,
    required FutureOr<void> Function(String line) onWrite,
  }) async {
    final decodedStream = stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in decodedStream) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        continue;
      }
      await onWrite(trimmed);
      onLog(trimmed);
    }
  }
}
