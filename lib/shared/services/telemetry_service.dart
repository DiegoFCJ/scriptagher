import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final stored = _prefs?.getBool(_prefKey);
    final initialValue = stored ?? telemetryDefaultOptIn;
    telemetryEnabled.value = initialValue;
    if (stored == null) {
      await _prefs?.setBool(_prefKey, initialValue);
    }
    _initialized = true;
  }

  Future<void> setTelemetryEnabled(bool enabled) async {
    if (!_initialized) {
      await initialize();
    }

    telemetryEnabled.value = enabled;
    await _prefs?.setBool(_prefKey, enabled);

    if (enabled) {
      _logger.info('Telemetry', 'Telemetry enabled by user');
    } else {
      _logger.info('Telemetry', 'Telemetry disabled by user');
    }
  }

  bool get isEnabled => telemetryEnabled.value;

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

    final sanitized = _sanitizeMetadata(extra);

    final metadata = <String, dynamic>{
      'event': eventName,
      'reason': reason,
      if (language != null && language.isNotEmpty) 'language': language,
      if (botName != null && botName.isNotEmpty) 'bot': _hash(botName),
      if (sanitized.isNotEmpty) 'extra': sanitized,
    };

    _logger.error(
      'Telemetry',
      'Captured telemetry event: $eventName',
      metadata: metadata,
    );
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
