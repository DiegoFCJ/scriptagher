import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/telemetry.dart';
import '../custom_logger.dart';

class TelemetryService {
  TelemetryService._internal();

  static final TelemetryService _instance = TelemetryService._internal();

  factory TelemetryService() => _instance;

  static const String _prefKey = 'telemetry_opt_in';

  final ValueNotifier<bool> telemetryEnabled = ValueNotifier<bool>(false);

  final CustomLogger _logger = CustomLogger();

  SharedPreferences? _prefs;
  bool _initialized = false;
  bool _sentryInitialized = false;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final stored = _prefs?.getBool(_prefKey) ?? false;
    telemetryEnabled.value = stored;
    _initialized = true;
    if (stored) {
      await _ensureSentryInitialized();
    }
  }

  Future<void> setTelemetryEnabled(bool enabled) async {
    if (!_initialized) {
      await initialize();
    }

    telemetryEnabled.value = enabled;
    await _prefs?.setBool(_prefKey, enabled);

    if (enabled) {
      await _ensureSentryInitialized();
      _logger.info('Telemetry', 'Telemetry enabled by user');
    } else {
      await _shutdownSentry();
      _logger.info('Telemetry', 'Telemetry disabled by user');
    }
  }

  bool get isEnabled => telemetryEnabled.value && telemetryDsn.isNotEmpty;

  Future<void> recordDownloadFailure({
    String? language,
    String? botName,
    required String reason,
    Map<String, Object?>? extra,
  }) async {
    await _sendEvent(
      'download_failure',
      language: language,
      botName: botName,
      reason: reason,
      extra: extra,
    );
  }

  Future<void> recordExecutionFailure({
    String? language,
    String? botName,
    required String reason,
    Map<String, Object?>? extra,
  }) async {
    await _sendEvent(
      'execution_failure',
      language: language,
      botName: botName,
      reason: reason,
      extra: extra,
    );
  }

  Future<void> _sendEvent(
    String eventName, {
    String? language,
    String? botName,
    required String reason,
    Map<String, Object?>? extra,
  }) async {
    if (!isEnabled) {
      return;
    }

    await _ensureSentryInitialized();

    await Sentry.captureMessage(
      eventName,
      withScope: (scope) {
        scope.setTag('event_type', eventName);
        scope.setTag('reason', reason);
        if (language != null && language.isNotEmpty) {
          scope.setTag('language', language);
        }
        if (botName != null && botName.isNotEmpty) {
          scope.setExtra('bot', _hash(botName));
        }
        final sanitized = _sanitizeMetadata(extra);
        sanitized.forEach(scope.setExtra);
        scope.setTag('source', 'scriptagher_app');
      },
    );
  }

  Future<void> _ensureSentryInitialized() async {
    if (_sentryInitialized || telemetryDsn.isEmpty) {
      return;
    }

    await Sentry.init((options) {
      options.dsn = telemetryDsn;
      options.tracesSampleRate = 0.0;
      options.sendDefaultPii = false;
      options.enableDefaultIntegrations = false;
      options.attachStacktrace = false;
    });

    _sentryInitialized = true;
  }

  Future<void> _shutdownSentry() async {
    if (!_sentryInitialized) {
      return;
    }
    await Sentry.close();
    _sentryInitialized = false;
  }

  Map<String, Object?> _sanitizeMetadata(Map<String, Object?>? extra) {
    if (extra == null || extra.isEmpty) {
      return const {};
    }

    final sanitized = <String, Object?>{};
    extra.forEach((key, value) {
      if (value == null) {
        return;
      }

      if (value is num || value is bool) {
        sanitized[key] = value;
      } else {
        sanitized[key] = _hash(value.toString());
      }
    });
    return sanitized;
  }

  String _hash(String value) {
    final normalized = value.trim().toLowerCase();
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
