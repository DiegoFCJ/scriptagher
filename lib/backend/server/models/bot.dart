import 'dart:convert';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final String? author;
  final String? version;
  final List<String> permissions;
  final BotCompat compat;
  final BotPlatformCompatibility platformCompatibility;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.author,
    this.version,
    this.permissions = const [],
    this.compat = const BotCompat(),
    this.platformCompatibility = const BotPlatformCompatibility(),
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
    BotCompat? compat,
    String? sourcePath,
    String? author,
    String? version,
    List<String>? permissions,
    BotPlatformCompatibility? platformCompatibility,
  }) {
    return Bot(
      id: id,
      botName: botName,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath ?? this.sourcePath,
      language: language,
      author: author ?? this.author,
      version: version ?? this.version,
      permissions: permissions ?? this.permissions,
      compat: compat ?? this.compat,
      platformCompatibility:
          platformCompatibility ?? this.platformCompatibility,
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
      'author': author,
      'version': version,
      'permissions_json': jsonEncode(permissions),
      'compat_json': jsonEncode(compat.toJson()),
      'platforms_json': jsonEncode(platformCompatibility.toJson()),
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
      'author': author,
      'version': version,
      'permissions': permissions,
      'compat': compat.toJson(),
      'platform_compat': platformCompatibility.toJson(),
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
      final value = map['compat'];
      if (value is Map<String, dynamic>) {
        compat = BotCompat.fromJson(value);
      }
    }

    List<String> permissions = const [];
    final permissionsJson = map['permissions_json'];
    if (permissionsJson is String && permissionsJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(permissionsJson);
        if (decoded is List) {
          permissions = decoded.whereType<String>().toList();
        }
      } catch (_) {}
    } else if (map['permissions'] is List) {
      permissions = (map['permissions'] as List).whereType<String>().toList();
    }

    BotPlatformCompatibility platformCompatibility =
        const BotPlatformCompatibility();
    final platformsJson = map['platforms_json'];
    if (platformsJson is String && platformsJson.isNotEmpty) {
      try {
        platformCompatibility = BotPlatformCompatibility.fromJson(
            jsonDecode(platformsJson));
      } catch (_) {
        platformCompatibility = const BotPlatformCompatibility();
      }
    } else if (map['platform_compat'] != null) {
      platformCompatibility =
          BotPlatformCompatibility.fromJson(map['platform_compat']);
    }

    return Bot(
      id: map['id'],
      botName: map['bot_name'],
      description: map['description'] ?? '',
      startCommand: map['start_command'] ?? '',
      sourcePath: map['source_path'] ?? '',
      language: map['language'] ?? '',
      author: map['author'],
      version: map['version'],
      permissions: permissions,
      compat: compat,
      platformCompatibility: platformCompatibility,
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

enum BotPlatformSupportStatus {
  supported,
  unsupported,
  partial,
  unknown,
}

class BotPlatformCompatibility {
  final Map<String, BotPlatformSupportStatus> platforms;
  final List<String> notes;

  const BotPlatformCompatibility({
    this.platforms = const {},
    this.notes = const [],
  });

  bool get isEmpty => platforms.isEmpty && notes.isEmpty;

  List<String> get supported => platforms.entries
      .where((entry) => entry.value == BotPlatformSupportStatus.supported)
      .map((entry) => entry.key)
      .toList();

  List<String> get unsupported => platforms.entries
      .where((entry) => entry.value == BotPlatformSupportStatus.unsupported)
      .map((entry) => entry.key)
      .toList();

  List<String> get partial => platforms.entries
      .where((entry) => entry.value == BotPlatformSupportStatus.partial)
      .map((entry) => entry.key)
      .toList();

  List<String> get unknown => platforms.entries
      .where((entry) => entry.value == BotPlatformSupportStatus.unknown)
      .map((entry) => entry.key)
      .toList();

  Map<String, dynamic> toJson() {
    return {
      'platforms': platforms.map(
        (key, value) => MapEntry(key, value.name),
      ),
      if (notes.isNotEmpty) 'notes': notes,
    };
  }

  BotPlatformCompatibility copyWith({
    Map<String, BotPlatformSupportStatus>? platforms,
    List<String>? notes,
  }) {
    return BotPlatformCompatibility(
      platforms: platforms ?? this.platforms,
      notes: notes ?? this.notes,
    );
  }

  factory BotPlatformCompatibility.fromJson(dynamic json) {
    if (json == null) {
      return const BotPlatformCompatibility();
    }

    Map<String, BotPlatformSupportStatus> platforms = {};
    List<String> notes = const [];

    if (json is Map<String, dynamic>) {
      if (json['platforms'] is Map<String, dynamic>) {
        platforms = _parsePlatformStatuses(json['platforms']);
      } else {
        platforms = _parsePlatformStatuses(json);
      }

      if (json['supported'] is List) {
        platforms.addEntries(
          (json['supported'] as List)
              .whereType<String>()
              .map((platform) => MapEntry(
                  platform, BotPlatformSupportStatus.supported)),
        );
      }
      if (json['unsupported'] is List) {
        platforms.addEntries(
          (json['unsupported'] as List)
              .whereType<String>()
              .map((platform) => MapEntry(
                  platform, BotPlatformSupportStatus.unsupported)),
        );
      }
      if (json['partial'] is List) {
        platforms.addEntries(
          (json['partial'] as List)
              .whereType<String>()
              .map((platform) =>
                  MapEntry(platform, BotPlatformSupportStatus.partial)),
        );
      }
      if (json['notes'] is List) {
        notes = (json['notes'] as List).whereType<String>().toList();
      }
    } else if (json is List) {
      platforms = {
        for (final platform in json.whereType<String>())
          platform: BotPlatformSupportStatus.supported,
      };
    } else if (json is String) {
      platforms = {
        for (final platform in json.split(',').map((e) => e.trim()).where(
            (element) => element.isNotEmpty))
          platform: BotPlatformSupportStatus.supported,
      };
    }

    return BotPlatformCompatibility(
      platforms: platforms,
      notes: notes,
    );
  }

  factory BotPlatformCompatibility.fromManifest(dynamic json) {
    return BotPlatformCompatibility.fromJson(json);
  }

  static Map<String, BotPlatformSupportStatus> _parsePlatformStatuses(
      Map<String, dynamic> json) {
    final Map<String, BotPlatformSupportStatus> platforms = {};

    json.forEach((key, value) {
      final normalizedKey = key.toString();
      platforms[normalizedKey] = _parseStatus(value);
    });

    return platforms;
  }

  static BotPlatformSupportStatus _parseStatus(dynamic value) {
    if (value is bool) {
      return value
          ? BotPlatformSupportStatus.supported
          : BotPlatformSupportStatus.unsupported;
    }

    if (value is String) {
      switch (value.toLowerCase()) {
        case 'yes':
        case 'supported':
        case 'true':
          return BotPlatformSupportStatus.supported;
        case 'no':
        case 'unsupported':
        case 'false':
          return BotPlatformSupportStatus.unsupported;
        case 'partial':
        case 'experimental':
        case 'preview':
          return BotPlatformSupportStatus.partial;
        default:
          return BotPlatformSupportStatus.unknown;
      }
    }

    return BotPlatformSupportStatus.unknown;
  }
}
