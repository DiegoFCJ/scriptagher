import 'dart:convert';

class CompatInfo {
  final DesktopCompat? desktop;
  final BrowserCompat? browser;

  const CompatInfo({
    this.desktop,
    this.browser,
  });

  factory CompatInfo.empty() => const CompatInfo();

  CompatInfo copyWith({
    DesktopCompat? desktop,
    BrowserCompat? browser,
  }) {
    return CompatInfo(
      desktop: desktop ?? this.desktop,
      browser: browser ?? this.browser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (desktop != null) 'desktop': desktop!.toJson(),
      if (browser != null) 'browser': browser!.toJson(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory CompatInfo.fromJson(dynamic json) {
    if (json == null) {
      return CompatInfo.empty();
    }

    if (json is String) {
      if (json.isEmpty) return CompatInfo.empty();
      return CompatInfo.fromJson(jsonDecode(json));
    }

    if (json is Map<String, dynamic>) {
      return CompatInfo(
        desktop: json['desktop'] != null
            ? DesktopCompat.fromJson(json['desktop'] as Map<String, dynamic>)
            : null,
        browser: json['browser'] != null
            ? BrowserCompat.fromJson(json['browser'] as Map<String, dynamic>)
            : null,
      );
    }

    return CompatInfo.empty();
  }

  factory CompatInfo.fromManifest(dynamic json) {
    if (json == null) {
      return CompatInfo.empty();
    }

    return CompatInfo.fromJson(json);
  }
}

class DesktopCompat {
  final List<String> runners;
  final List<String> missingRunners;
  final Map<String, RuntimeCheckResult> runnerStatus;
  final String? notes;

  const DesktopCompat({
    this.runners = const [],
    this.missingRunners = const [],
    this.runnerStatus = const {},
    this.notes,
  });

  bool get isCompatible => missingRunners.isEmpty;

  DesktopCompat copyWith({
    List<String>? runners,
    List<String>? missingRunners,
    Map<String, RuntimeCheckResult>? runnerStatus,
    String? notes,
  }) {
    return DesktopCompat(
      runners: runners ?? this.runners,
      missingRunners: missingRunners ?? this.missingRunners,
      runnerStatus: runnerStatus ?? this.runnerStatus,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (runners.isNotEmpty) 'runners': runners,
      if (missingRunners.isNotEmpty) 'missing': missingRunners,
      if (runnerStatus.isNotEmpty)
        'status': runnerStatus.map((key, value) => MapEntry(key, value.toJson())),
      if (notes != null) 'notes': notes,
    };
  }

  factory DesktopCompat.fromJson(Map<String, dynamic> json) {
    final runnersDynamic = json['runners'];
    final missingDynamic = json['missing'];
    final statusDynamic = json['status'];

    return DesktopCompat(
      runners: runnersDynamic is List
          ? runnersDynamic.map((e) => e.toString()).toList()
          : const [],
      missingRunners: missingDynamic is List
          ? missingDynamic.map((e) => e.toString()).toList()
          : const [],
      runnerStatus: statusDynamic is Map<String, dynamic>
          ? statusDynamic.map(
              (key, value) => MapEntry(
                key,
                RuntimeCheckResult.fromJson(value as Map<String, dynamic>),
              ),
            )
          : const {},
      notes: json['notes']?.toString(),
    );
  }
}

class BrowserCompat {
  final bool supported;
  final String? reason;

  const BrowserCompat({
    required this.supported,
    this.reason,
  });

  factory BrowserCompat.defaultUnsupported() =>
      const BrowserCompat(supported: false);

  BrowserCompat copyWith({
    bool? supported,
    String? reason,
  }) {
    return BrowserCompat(
      supported: supported ?? this.supported,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supported': supported,
      if (reason != null) 'reason': reason,
    };
  }

  factory BrowserCompat.fromJson(Map<String, dynamic> json) {
    final supportedValue = json['supported'];
    return BrowserCompat(
      supported: supportedValue is bool
          ? supportedValue
          : supportedValue.toString().toLowerCase() == 'true',
      reason: json['reason']?.toString(),
    );
  }
}

class RuntimeCheckResult {
  final bool available;
  final String? version;
  final String? message;

  const RuntimeCheckResult({
    required this.available,
    this.version,
    this.message,
  });

  RuntimeCheckResult copyWith({
    bool? available,
    String? version,
    String? message,
  }) {
    return RuntimeCheckResult(
      available: available ?? this.available,
      version: version ?? this.version,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'available': available,
      if (version != null) 'version': version,
      if (message != null) 'message': message,
    };
  }

  factory RuntimeCheckResult.fromJson(Map<String, dynamic> json) {
    return RuntimeCheckResult(
      available: json['available'] == true,
      version: json['version']?.toString(),
      message: json['message']?.toString(),
    );
  }
}
