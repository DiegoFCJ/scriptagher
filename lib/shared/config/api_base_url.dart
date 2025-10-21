import 'package:flutter/foundation.dart';

/// Utility to resolve the base URL for API calls across platforms.
class ApiBaseUrl {
  const ApiBaseUrl._();

  static const _envKey = 'API_BASE_URL';

  /// Returns the API base URL following the priority:
  /// 1. Compile-time override via [String.fromEnvironment] using [_envKey].
  /// 2. The current browser origin when running on the web.
  /// 3. The local development endpoint for desktop and tests.
  static String resolve() {
    const override = String.fromEnvironment(_envKey);
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty) {
        return origin;
      }
    }

    return 'http://localhost:8080';
  }
}
