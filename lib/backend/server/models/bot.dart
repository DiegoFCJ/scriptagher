import 'dart:convert';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final BotCompat compat;
  final List<String> permissions;
  final String? archiveSha256;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.compat = const BotCompat(),
    this.permissions = const [],
    this.archiveSha256,
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
    BotCompat? compat,
    List<String>? permissions,
    String? archiveSha256,
  }) {
    return Bot(
      id: id,
      botName: botName,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath,
      language: language,
      compat: compat ?? this.compat,
      permissions: permissions ?? this.permissions,
      archiveSha256: archiveSha256 ?? this.archiveSha256,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bot_name': botName,
      'description': description,
      'start_command': startCommand,
      'source_path': sourcePath,
      'language': language,
      'compat_json': jsonEncode(compat.toJson()),
      'permissions_json': jsonEncode(permissions),
      'archive_sha256': archiveSha256,
    };
  }

  Map<String, dynamic> toResponseMap() {
    return {
      'id': id,
      'bot_name': botName,
      'description': description,
      'start_command': startCommand,
      'source_path': sourcePath,
      'language': language,
      'compat': compat.toJson(),
      'permissions': permissions,
      'archive_sha256': archiveSha256,
    };
  }

  factory Bot.fromMap(Map<String, dynamic> map) {
    BotCompat compat = const BotCompat();
    final compatJson = map['compat_json'];
    if (compatJson is String && compatJson.isNotEmpty) {
      try {
        compat = BotCompat.fromJson(jsonDecode(compatJson));
      } catch (_) {
        compat = const BotCompat();
      }
    } else if (map['compat'] != null) {
      compat = BotCompat.fromJson(map['compat'] as Map<String, dynamic>);
    }

    List<String> permissions = const [];
    final permissionsJson = map['permissions_json'];
    if (permissionsJson is String && permissionsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(permissionsJson);
        if (decoded is List) {
          permissions = decoded.whereType<String>().toList();
        }
      } catch (_) {
        permissions = const [];
      }
    } else if (map['permissions'] is List) {
      permissions = (map['permissions'] as List).whereType<String>().toList();
    }

    String? archiveSha256;
    final archiveValue = map['archive_sha256'];
    if (archiveValue is String && archiveValue.isNotEmpty) {
      archiveSha256 = archiveValue;
    }

    return Bot(
      id: map['id'],
      botName: map['bot_name'],
      description: map['description'] ?? '',
      startCommand: map['start_command'] ?? '',
      sourcePath: map['source_path'],
      language: map['language'],
      compat: compat,
      permissions: permissions,
      archiveSha256: archiveSha256,
    );
  }
}

class BotCompat {
  final List<String> desktopRuntimes;
  final List<String> missingDesktopRuntimes;
  final bool? browserSupported;
  final String? browserReason;

  const BotCompat({
    this.desktopRuntimes = const [],
    this.missingDesktopRuntimes = const [],
    this.browserSupported,
    this.browserReason,
  });

  BotCompat copyWith({
    List<String>? desktopRuntimes,
    List<String>? missingDesktopRuntimes,
    bool? browserSupported,
    bool setBrowserSupportedNull = false,
    String? browserReason,
    bool setBrowserReasonNull = false,
  }) {
    return BotCompat(
      desktopRuntimes: desktopRuntimes ?? this.desktopRuntimes,
      missingDesktopRuntimes:
          missingDesktopRuntimes ?? this.missingDesktopRuntimes,
      browserSupported: setBrowserSupportedNull
          ? null
          : (browserSupported ?? this.browserSupported),
      browserReason: setBrowserReasonNull
          ? null
          : (browserReason ?? this.browserReason),
    );
  }

  String get desktopStatus {
    if (desktopRuntimes.isEmpty) {
      return 'unknown';
    }
    return missingDesktopRuntimes.isEmpty ? 'compatible' : 'missing-runner';
  }

  String get browserStatus {
    if (browserSupported == null) {
      return 'unknown';
    }
    return browserSupported! ? 'supported' : 'unsupported';
  }

  Map<String, dynamic> toJson() {
    return {
      'desktop': {
        'runtimes': desktopRuntimes,
        'missingRuntimes': missingDesktopRuntimes,
        'status': desktopStatus,
      },
      'browser': {
        'supported': browserSupported,
        'status': browserStatus,
        if (browserReason != null) 'reason': browserReason,
      },
    };
  }

  factory BotCompat.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const BotCompat();
    }

    final desktop = json['desktop'];
    final browser = json['browser'];

    List<String> runtimes = const [];
    List<String> missing = const [];
    bool? browserSupported;
    String? browserReason;

    if (desktop is Map<String, dynamic>) {
      final runtimeList = desktop['runtimes'] ?? desktop['requires'];
      if (runtimeList is List) {
        runtimes = runtimeList.whereType<String>().toList();
      }
      final missingList = desktop['missingRuntimes'];
      if (missingList is List) {
        missing = missingList.whereType<String>().toList();
      }
    }

    if (browser is Map<String, dynamic>) {
      final supported = browser['supported'];
      if (supported is bool) {
        browserSupported = supported;
      }
      final reason = browser['reason'];
      if (reason is String) {
        browserReason = reason;
      }
    }

    return BotCompat(
      desktopRuntimes: runtimes,
      missingDesktopRuntimes: missing,
      browserSupported: browserSupported,
      browserReason: browserReason,
    );
  }

  factory BotCompat.fromManifest(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const BotCompat();
    }
    final desktop = json['desktop'];
    final browser = json['browser'];

    List<String> runtimes = const [];
    bool? browserSupported;
    String? browserReason;

    if (desktop is Map<String, dynamic>) {
      final runtimeList = desktop['runtimes'] ?? desktop['requires'];
      if (runtimeList is List) {
        runtimes = runtimeList.whereType<String>().toList();
      }
    }

    if (browser is Map<String, dynamic>) {
      final supported = browser['supported'];
      if (supported is bool) {
        browserSupported = supported;
      }
      final reason = browser['reason'] ?? browser['note'];
      if (reason is String) {
        browserReason = reason;
      }
    } else if (browser is bool) {
      browserSupported = browser;
    }

    return BotCompat(
      desktopRuntimes: runtimes,
      browserSupported: browserSupported,
      browserReason: browserReason,
    );
  }
}
