import 'dart:io';

import 'package:scriptagher/shared/models/compat.dart';

class SystemRuntimeService {
  final Map<String, RuntimeProbeResult> _cache = {};

  Future<RuntimeProbeResult> checkRunner(String runner) async {
    if (_cache.containsKey(runner)) {
      return _cache[runner]!;
    }

    try {
      final result = await Process.run(runner, ['--version']);
      if (result.exitCode == 0) {
        final output = _sanitizeOutput(result.stdout) ?? _sanitizeOutput(result.stderr);
        return _cache[runner] = RuntimeProbeResult(
          name: runner,
          available: true,
          version: output,
        );
      } else {
        final message = _sanitizeOutput(result.stdout) ?? _sanitizeOutput(result.stderr);
        return _cache[runner] = RuntimeProbeResult(
          name: runner,
          available: false,
          message: message ?? 'exit code ${result.exitCode}',
        );
      }
    } on ProcessException catch (e) {
      return _cache[runner] = RuntimeProbeResult(
        name: runner,
        available: false,
        message: e.message,
      );
    } catch (e) {
      return _cache[runner] = RuntimeProbeResult(
        name: runner,
        available: false,
        message: e.toString(),
      );
    }
  }

  Future<Map<String, RuntimeProbeResult>> ensureRunners(List<String> runners) async {
    final Map<String, RuntimeProbeResult> results = {};
    for (final runner in runners) {
      results[runner] = await checkRunner(runner);
    }
    return results;
  }

  Map<String, RuntimeProbeResult> get cachedResults => Map.unmodifiable(_cache);
}

class RuntimeProbeResult {
  final String name;
  final bool available;
  final String? version;
  final String? message;

  const RuntimeProbeResult({
    required this.name,
    required this.available,
    this.version,
    this.message,
  });

  RuntimeCheckResult toRuntimeCheckResult() {
    return RuntimeCheckResult(
      available: available,
      version: version,
      message: message,
    );
  }
}

String? _sanitizeOutput(dynamic output) {
  if (output == null) return null;
  if (output is String) {
    final trimmed = output.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  final text = output.toString().trim();
  return text.isEmpty ? null : text;
}
