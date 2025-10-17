import 'package:scriptagher/shared/models/compat.dart';

import '../services/system_runtime_service.dart';

extension CompatInfoEvaluation on CompatInfo {
  Future<CompatInfo> evaluateWith(SystemRuntimeService runtimeService) async {
    final desktopCompat = desktop;
    if (desktopCompat == null || desktopCompat.runners.isEmpty) {
      return this;
    }

    final results = await runtimeService.ensureRunners(desktopCompat.runners);

    final missing = <String>[];
    final statusMap = <String, RuntimeCheckResult>{};

    for (final entry in results.entries) {
      final status = entry.value.toRuntimeCheckResult();
      statusMap[entry.key] = status;
      if (!status.available) {
        missing.add(entry.key);
      }
    }

    return copyWith(
      desktop: desktopCompat.copyWith(
        missingRunners: missing,
        runnerStatus: statusMap,
      ),
    );
  }
}
