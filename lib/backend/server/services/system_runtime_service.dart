import 'dart:async';
import 'dart:io';

import '../models/bot.dart';

class SystemRuntimeService {
  final Map<String, bool> _runtimeAvailability = {};

  Future<Map<String, bool>> ensureRuntimes(List<String> runtimes) async {
    final Map<String, bool> results = {};
    for (final runtime in runtimes) {
      if (_runtimeAvailability.containsKey(runtime)) {
        results[runtime] = _runtimeAvailability[runtime]!;
        continue;
      }
      final isAvailable = await _checkRuntime(runtime);
      _runtimeAvailability[runtime] = isAvailable;
      results[runtime] = isAvailable;
    }
    return results;
  }

  Map<String, bool> get cachedAvailability =>
      Map<String, bool>.unmodifiable(_runtimeAvailability);

  Future<bool> _checkRuntime(String runtime) async {
    final sanitized = runtime.trim();
    if (sanitized.isEmpty) {
      return false;
    }

    try {
      final result = await Process.run(sanitized, const ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    } catch (_) {
      return false;
    }
  }

  BotCompat applyRuntimeResults(BotCompat compat) {
    if (compat.desktopRuntimes.isEmpty) {
      return compat;
    }
    final missing = <String>[];
    for (final runtime in compat.desktopRuntimes) {
      final available = _runtimeAvailability[runtime];
      if (available == false || available == null) {
        if (available == null) {
          // trigger a check lazily to keep cache updated for future calls
          unawaited(ensureRuntimes([runtime]));
        }
        missing.add(runtime);
      }
    }
    return compat.copyWith(missingDesktopRuntimes: missing);
  }
}
