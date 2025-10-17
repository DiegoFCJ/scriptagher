import 'dart:convert';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final List<String> tags;
  final String? author;
  final String? version;
  final BotCompat compat;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.tags = const [],
    this.author,
    this.version,
    this.compat = const BotCompat(),
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
    BotCompat? compat,
    List<String>? tags,
    String? author,
    String? version,
  }) {
    return Bot(
      id: id,
      botName: botName,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath,
      language: language,
      tags: tags ?? this.tags,
      author: author ?? this.author,
      version: version ?? this.version,
      compat: compat ?? this.compat,
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
      'tags': tags,
      'author': author,
      'version': version,
      'compat': compat.toJson(),
    };
  }

  factory Bot.fromMap(Map<String, dynamic> map) {
    return Bot(
      id: map['id'],
      botName: map['bot_name'],
      description: map['description'] ?? '',
      startCommand: map['start_command'] ?? '',
      sourcePath: map['source_path'],
      language: map['language'],
      tags: parseTags(map['tags']),
      author: parseOptionalString(map['author']),
      version: parseOptionalString(map['version']),
      compat: BotCompat.fromJson(map['compat']),
    );
  }

  factory Bot.fromJson(Map<String, dynamic> json) {
    return Bot(
      botName: json['bot_name'] ?? '',
      description: json['description'] ?? '',
      startCommand: json['start_command'] ?? '',
      sourcePath: json['source_path'] ?? '',
      language: json['language'] ?? '',
      tags: parseTags(json['tags'] ?? json['metadata']?['tags']),
      author: parseOptionalString(
        json['author'] ?? json['metadata']?['author'],
      ),
      version: parseOptionalString(
        json['version'] ?? json['metadata']?['version'],
      ),
      compat: BotCompat.fromJson(json['compat']),
    );
  }

  static List<String> parseTags(dynamic source) {
    if (source == null) return const [];
    if (source is String) {
      if (source.trim().isEmpty) return const [];
      try {
        final decoded = jsonDecode(source);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList();
        }
      } catch (_) {
        return source
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }
    }

    if (source is List) {
      return source
          .whereType<String>()
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }

    return const [];
  }

  static String? parseOptionalString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
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

  bool get isDesktopCompatible => desktopStatus == 'compatible';
  bool get isDesktopRunnerMissing => desktopStatus == 'missing-runner';
  bool get isBrowserUnsupported => browserStatus == 'unsupported';

  BotCompat copyWith({
    List<String>? desktopRuntimes,
    List<String>? missingDesktopRuntimes,
    bool? browserSupported,
    String? browserReason,
  }) {
    return BotCompat(
      desktopRuntimes: desktopRuntimes ?? this.desktopRuntimes,
      missingDesktopRuntimes:
          missingDesktopRuntimes ?? this.missingDesktopRuntimes,
      browserSupported: browserSupported ?? this.browserSupported,
      browserReason: browserReason ?? this.browserReason,
    );
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
    } else if (browser is bool) {
      browserSupported = browser;
    }

    return BotCompat(
      desktopRuntimes: runtimes,
      missingDesktopRuntimes: missing,
      browserSupported: browserSupported,
      browserReason: browserReason,
    );
  }
}
