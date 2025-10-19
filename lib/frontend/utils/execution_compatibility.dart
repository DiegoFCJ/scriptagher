import '../models/bot.dart';

class ExecutionCompatibilityResult {
  final bool isSupported;
  final String? reason;

  const ExecutionCompatibilityResult({
    required this.isSupported,
    this.reason,
  });
}

ExecutionCompatibilityResult computeExecutionCompatibility({
  required Bot bot,
  required bool isWebPlatform,
  required bool isDesktopPlatform,
  required bool isMobilePlatform,
  required bool shouldUseBrowserRunner,
}) {
  final compat = bot.compat;

  if (isWebPlatform) {
    if (shouldUseBrowserRunner) {
      return const ExecutionCompatibilityResult(isSupported: true);
    }

    final reason = compat.browserReason?.isNotEmpty == true
        ? compat.browserReason!
        : compat.browserSupported == false
            ? 'Questo bot non è compatibile con l\'esecuzione nel browser.'
            : 'Esecuzione nel browser non supportata su questa piattaforma.';
    return ExecutionCompatibilityResult(isSupported: false, reason: reason);
  }

  if (isDesktopPlatform) {
    if (compat.isDesktopRunnerMissing) {
      final missing = compat.missingDesktopRuntimes.join(', ');
      final missingLabel = missing.isNotEmpty
          ? 'Runtime mancanti: $missing.'
          : 'Runtime desktop richiesti mancanti.';
      return ExecutionCompatibilityResult(
        isSupported: false,
        reason: missingLabel,
      );
    }

    if (!compat.isDesktopCompatible && compat.desktopRuntimes.isNotEmpty) {
      return const ExecutionCompatibilityResult(
        isSupported: false,
        reason: 'Questo bot non è compatibile con il runner desktop.',
      );
    }

    return const ExecutionCompatibilityResult(isSupported: true);
  }

  if (isMobilePlatform) {
    final result = _parseMobileMetadata(compat.browserPayloads.metadata['mobile']);
    if (result != null) {
      return result;
    }

    return const ExecutionCompatibilityResult(
      isSupported: false,
      reason: 'Questo bot non è compatibile con i dispositivi mobili.',
    );
  }

  return const ExecutionCompatibilityResult(isSupported: true);
}

ExecutionCompatibilityResult? _parseMobileMetadata(dynamic metadata) {
  if (metadata == null) {
    return null;
  }

  bool? supported;
  String? reason;

  if (metadata is Map<String, dynamic>) {
    final supportedValue = metadata['supported'];
    if (supportedValue is bool) {
      supported = supportedValue;
    }

    final statusValue = metadata['status'];
    if (statusValue is String) {
      final normalizedStatus = statusValue.toLowerCase();
      if (supported == null) {
        if (normalizedStatus == 'supported' || normalizedStatus == 'compatible') {
          supported = true;
        } else if (normalizedStatus == 'unsupported' ||
            normalizedStatus == 'incompatible') {
          supported = false;
        }
      }
    }

    final reasonValue = metadata['reason'];
    if (reasonValue is String && reasonValue.isNotEmpty) {
      reason = reasonValue;
    }
  } else if (metadata is bool) {
    supported = metadata;
  } else if (metadata is String) {
    final normalizedValue = metadata.toLowerCase();
    if (normalizedValue == 'supported' || normalizedValue == 'compatible') {
      supported = true;
    } else if (normalizedValue == 'unsupported' ||
        normalizedValue == 'incompatible' ||
        normalizedValue == 'not_supported') {
      supported = false;
    }
  }

  if (supported == true) {
    return const ExecutionCompatibilityResult(isSupported: true);
  }

  if (supported == false) {
    return ExecutionCompatibilityResult(
      isSupported: false,
      reason: reason ?? 'Questo bot non è compatibile con i dispositivi mobili.',
    );
  }

  return null;
}
