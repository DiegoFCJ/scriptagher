import 'package:flutter/foundation.dart';

/// Utility to resolve the base URL for API calls across platforms.
class ApiBaseUrl {
  const ApiBaseUrl._();

  static const _envKey = 'API_BASE_URL';

  /// Returns the API base URL if available.
  ///
  /// Priority:
  /// 1. Compile-time override via [String.fromEnvironment] using [_envKey].
  /// 2. Local development endpoint when running on a desktop platform.
  ///
  /// For non-desktop builds without an override the method returns `null`.
  static String? resolve() {
    const override = String.fromEnvironment(_envKey);
    if (override.isNotEmpty) {
      return override;
    }

    if (_isDesktopPlatform) {
      return 'http://localhost:8080';
    }

    return null;
  }

  /// Resolves the base URL or throws a descriptive [StateError] when missing.
  static String require() {
    final value = resolve();
    if (value == null || value.isEmpty) {
      throw StateError(
        'Nessun endpoint API configurato. '
        'Passa --dart-define=API_BASE_URL=<url> per abilitare tutte le funzionalità.',
      );
    }
    return value;
  }

  static bool get _isDesktopPlatform {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }
}
