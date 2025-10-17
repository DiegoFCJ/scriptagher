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
    this.author,
    this.version,
    this.compat = const BotCompat(),
    this.permissions = const [],
    this.archiveSha256,
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
    String? author,
    String? version,
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
      author: author ?? this.author,
      version: version ?? this.version,
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
      'author': author,
      'version': version,
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
      'author': author,
      'version': version,
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
      author: map['author'] as String?,
      version: map['version'] as String?,
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
  final String? browserRunner;
  final BrowserPayloads browserPayloads;

  const BotCompat({
    this.desktopRuntimes = const [],
    this.missingDesktopRuntimes = const [],
    this.browserSupported,
    this.browserReason,
    this.browserRunner,
    this.browserPayloads = const BrowserPayloads(),
  });

  BotCompat copyWith({
    List<String>? desktopRuntimes,
    List<String>? missingDesktopRuntimes,
    bool? browserSupported,
    bool setBrowserSupportedNull = false,
    String? browserReason,
    bool setBrowserReasonNull = false,
    String? browserRunner,
    BrowserPayloads? browserPayloads,
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
      browserRunner: browserRunner ?? this.browserRunner,
      browserPayloads: browserPayloads ?? this.browserPayloads,
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
        if (browserRunner != null) 'runner': browserRunner,
        if (!browserPayloads.isEmpty) 'payloads': browserPayloads.toJson(),
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
    String? browserRunner;
    BrowserPayloads payloads = const BrowserPayloads();

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
      final runner = browser['runner'];
      if (runner is String && runner.isNotEmpty) {
        browserRunner = runner;
      }
      final payloadJson = browser['payloads'] ?? browser['artifacts'];
      if (payloadJson != null) {
        payloads = BrowserPayloads.fromJson(payloadJson);
      }
    } else if (browser is bool) {
      browserSupported = browser;
    }

    return BotCompat(
      desktopRuntimes: runtimes,
      missingDesktopRuntimes: missing,
      browserSupported: browserSupported,
      browserReason: browserReason,
      browserRunner: browserRunner,
      browserPayloads: payloads,
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
    String? browserRunner;
    BrowserPayloads payloads = const BrowserPayloads();

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
      final runner = browser['runner'];
      if (runner is String && runner.isNotEmpty) {
        browserRunner = runner;
      }
      final payloadJson = browser['payloads'] ?? browser['artifacts'];
      if (payloadJson != null) {
        payloads = BrowserPayloads.fromJson(payloadJson);
      }
    } else if (browser is bool) {
      browserSupported = browser;
    }

    return BotCompat(
      desktopRuntimes: runtimes,
      browserSupported: browserSupported,
      browserReason: browserReason,
      browserRunner: browserRunner,
      browserPayloads: payloads,
    );
  }
}

class BrowserPayloads {
  const BrowserPayloads({
    this.javascript,
    this.wasm,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? const {};

  final BrowserPayload? javascript;
  final BrowserPayload? wasm;
  final Map<String, dynamic> metadata;

  bool get hasJavaScript => javascript?.hasData ?? false;
  bool get hasWasm => wasm?.hasData ?? false;
  bool get isEmpty => !hasJavaScript && !hasWasm && metadata.isEmpty;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (javascript != null && javascript!.hasData) {
      map['javascript'] = javascript!.toJson();
    }
    if (wasm != null && wasm!.hasData) {
      map['wasm'] = wasm!.toJson();
    }
    if (metadata.isNotEmpty) {
      map['metadata'] = metadata;
    }
    return map;
  }

  static BrowserPayloads fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const BrowserPayloads();
    }

    BrowserPayload? jsPayload;
    BrowserPayload? wasmPayload;
    final jsJson = json['javascript'] ?? json['js'];
    if (jsJson != null) {
      jsPayload = BrowserPayload.fromJson(jsJson);
    }
    final wasmJson = json['wasm'];
    if (wasmJson != null) {
      wasmPayload = BrowserPayload.fromJson(wasmJson);
    }
    final metadataJson = json['metadata'];
    Map<String, dynamic>? metadata;
    if (metadataJson is Map<String, dynamic>) {
      metadata = metadataJson;
    }

    return BrowserPayloads(
      javascript: jsPayload,
      wasm: wasmPayload,
      metadata: metadata ?? const {},
    );
  }
}

class BrowserPayload {
  const BrowserPayload({
    this.inline,
    this.url,
    this.base64,
  });

  final String? inline;
  final String? url;
  final String? base64;

  bool get hasData =>
      (inline != null && inline!.isNotEmpty) ||
      (url != null && url!.isNotEmpty) ||
      (base64 != null && base64!.isNotEmpty);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (inline != null && inline!.isNotEmpty) {
      map['inline'] = inline;
    }
    if (url != null && url!.isNotEmpty) {
      map['url'] = url;
    }
    if (base64 != null && base64!.isNotEmpty) {
      map['base64'] = base64;
    }
    return map;
  }

  static BrowserPayload fromJson(dynamic json) {
    if (json is String) {
      if (json.trim().startsWith('http')) {
        return BrowserPayload(url: json.trim());
      }
      return BrowserPayload(inline: json);
    }

    if (json is! Map<String, dynamic>) {
      return const BrowserPayload();
    }

    final inline = json['inline'] ?? json['code'] ?? json['script'];
    final url = json['url'] ?? json['href'];
    final base64 = json['base64'] ?? json['b64'];

    return BrowserPayload(
      inline: inline is String ? inline : null,
      url: url is String ? url : null,
      base64: base64 is String ? base64 : null,
    );
  }
}
