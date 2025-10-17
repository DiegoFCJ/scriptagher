import 'dart:async';
import 'dart:io';

import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/custom_logger.dart';

class ExecutionService {
  final CustomLogger _logger = CustomLogger();
  final Map<String, Process> _runningProcesses = {};
  final Map<String, int?> _processExitCodes = {};

  String _processKey(String language, String botName) => '$language::$botName';

  /// Registers a [process] for a given [language] and [botName].
  ///
  /// If another process with the same key is already running it will be
  /// replaced. The exit code is tracked and the handle removed once the process
  /// completes.
  void registerProcess(
    String language,
    String botName,
    Process process,
  ) {
    final key = _processKey(language, botName);

    _logger.info(
      LOGS.EXECUTION_SERVICE,
      'Registered process handle for $key (pid: ${process.pid}).',
    );
    _runningProcesses[key] = process;
    _processExitCodes.remove(key);

    process.exitCode.then((code) {
      _logger.info(
        LOGS.EXECUTION_SERVICE,
        'Process for $key completed with exit code $code.',
      );
      _processExitCodes[key] = code;
      _runningProcesses.remove(key);
    }).catchError((error) {
      _logger.error(
        LOGS.EXECUTION_SERVICE,
        'Error while waiting for exit code of $key: $error',
      );
      _runningProcesses.remove(key);
    });
  }

  /// Returns whether a process for the given [language] and [botName] is still
  /// running.
  bool isRunning(String language, String botName) =>
      _runningProcesses.containsKey(_processKey(language, botName));

  /// Sends a [ProcessSignal.sigterm] to the running process.
  bool stopBot(String language, String botName) {
    final process = _runningProcesses[_processKey(language, botName)];
    if (process == null) {
      return false;
    }
    _logger.info(
      LOGS.EXECUTION_SERVICE,
      'Sending SIGTERM to process ${process.pid} ($language/$botName).',
    );
    return process.kill(ProcessSignal.sigterm);
  }

  /// Sends a [ProcessSignal.sigkill] to the running process.
  bool killBot(String language, String botName) {
    final process = _runningProcesses[_processKey(language, botName)];
    if (process == null) {
      return false;
    }
    _logger.warn(
      LOGS.EXECUTION_SERVICE,
      'Sending SIGKILL to process ${process.pid} ($language/$botName).',
    );
    return process.kill(ProcessSignal.sigkill);
  }

  /// Returns the cached exit code for the given process, if available.
  int? getExitCode(String language, String botName) =>
      _processExitCodes[_processKey(language, botName)];

  /// Waits for the process to finish and returns the exit code. A [timeout]
  /// (default 5 seconds) can be provided to avoid waiting indefinitely.
  Future<int?> waitForExitCode(
    String language,
    String botName, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final key = _processKey(language, botName);

    if (_processExitCodes.containsKey(key)) {
      return _processExitCodes[key];
    }

    final process = _runningProcesses[key];
    if (process == null) {
      return _processExitCodes[key];
    }

    try {
      final exitCode = await process.exitCode.timeout(timeout);
      _processExitCodes[key] = exitCode;
      _runningProcesses.remove(key);
      return exitCode;
    } on TimeoutException {
      _logger.warn(
        LOGS.EXECUTION_SERVICE,
        'Timeout while waiting exit code for $key.',
      );
      return null;
    }
  }
}
