import 'dart:async';
import 'dart:io';

class RunnerCheckResult {
  final String command;
  final List<String> args;
  final bool isAvailable;
  final String? version;
  final String? error;
  final DateTime checkedAt;

  RunnerCheckResult({
    required this.command,
    required this.args,
    required this.isAvailable,
    this.version,
    this.error,
    DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? DateTime.now();
}

class SystemCompatibilityService {
  static final SystemCompatibilityService _instance =
      SystemCompatibilityService._internal();

  final Map<String, RunnerCheckResult> _runnerResults = {};

  SystemCompatibilityService._internal();

  factory SystemCompatibilityService() => _instance;

  Future<RunnerCheckResult> checkRunner(String command,
      {List<String> args = const ['--version']}) async {
    final cacheKey = _cacheKey(command, args);
    if (_runnerResults.containsKey(cacheKey)) {
      return _runnerResults[cacheKey]!;
    }

    try {
      final result = await Process.run(command, args);
      final isAvailable = result.exitCode == 0;
      final output = _extractOutput(result.stdout, result.stderr);

      final checkResult = RunnerCheckResult(
        command: command,
        args: args,
        isAvailable: isAvailable,
        version: isAvailable ? output : null,
        error: isAvailable
            ? null
            : output.isEmpty
                ? result.stderr?.toString()
                : output,
      );

      _runnerResults[cacheKey] = checkResult;
      return checkResult;
    } on ProcessException catch (e) {
      final checkResult = RunnerCheckResult(
        command: command,
        args: args,
        isAvailable: false,
        error: e.message,
      );
      _runnerResults[cacheKey] = checkResult;
      return checkResult;
    } catch (e) {
      final checkResult = RunnerCheckResult(
        command: command,
        args: args,
        isAvailable: false,
        error: e.toString(),
      );
      _runnerResults[cacheKey] = checkResult;
      return checkResult;
    }
  }

  RunnerCheckResult? getRunnerResult(String command,
      {List<String> args = const ['--version']}) {
    final cacheKey = _cacheKey(command, args);
    return _runnerResults[cacheKey];
  }

  String _cacheKey(String command, List<String> args) {
    return '$command ${args.join(' ')}';
  }

  String _extractOutput(dynamic stdout, dynamic stderr) {
    final stdoutStr = stdout?.toString().trim() ?? '';
    final stderrStr = stderr?.toString().trim() ?? '';
    return stdoutStr.isNotEmpty ? stdoutStr : stderrStr;
  }
}
