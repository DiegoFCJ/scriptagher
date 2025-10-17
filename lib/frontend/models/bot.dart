import 'dart:convert';
import 'dart:typed_data';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final String author;
  final String version;
  final BotCompat compat;
  final List<String> permissions;
  final List<String> platformCompatibility;
  final String? archiveSha256;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.author = 'Sconosciuto',
    this.version = '0.0.0',
    this.compat = const BotCompat(),
    this.permissions = const [],
    this.platformCompatibility = const [],
    this.archiveSha256,
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? author,
    String? version,
    String? description,
    String? startCommand,
    BotCompat? compat,
    List<String>? permissions,
    List<String>? platformCompatibility,
    String? archiveSha256,
  }) {
    return Bot(
      id: id,
      botName: botName,
      author: author ?? this.author,
      version: version ?? this.version,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath,
      language: language,
      compat: compat ?? this.compat,
      permissions: permissions ?? this.permissions,
      platformCompatibility:
          platformCompatibility ?? this.platformCompatibility,
      archiveSha256: archiveSha256 ?? this.archiveSha256,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bot_name': botName,
      'author': author,
      'version': version,
      'description': description,
      'start_command': startCommand,
      'source_path': sourcePath,
      'language': language,
      'compat': compat.toJson(),
      'permissions': permissions,
      'platform_compatibility': platformCompatibility,
      'archive_sha256': archiveSha256,
    };
  }

  factory Bot.fromMap(Map<String, dynamic> map) {
    return Bot(
      id: map['id'],
      botName: map['bot_name'],
      author: map['author']?.toString() ?? 'Sconosciuto',
      version: map['version']?.toString() ?? '0.0.0',
      description: map['description'] ?? '',
      startCommand: map['start_command'] ?? '',
      sourcePath: map['source_path'],
      language: map['language'],
      compat: BotCompat.fromJson(map['compat']),
      permissions:
          (map['permissions'] as List?)?.whereType<String>().toList() ?? const [],
      platformCompatibility: (map['platform_compatibility'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      archiveSha256: map['archive_sha256'] as String?,
    );
  }

  factory Bot.fromJson(Map<String, dynamic> json) {
    return Bot(
      id: json['id'] as int?,
      botName: json['bot_name'] ?? '',
      author: json['author']?.toString() ?? 'Sconosciuto',
      version: json['version']?.toString() ?? '0.0.0',
      description: json['description'] ?? '',
      startCommand: json['start_command'] ?? '',
      sourcePath: json['source_path'] ?? '',
      language: json['language'] ?? '',
      compat: BotCompat.fromJson(json['compat']),
      permissions:
          (json['permissions'] as List?)?.whereType<String>().toList() ?? const [],
      platformCompatibility:
          (json['platform_compatibility'] as List?)?.whereType<String>().toList() ??
              const [],
      archiveSha256: json['archive_sha256'] as String?,
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
  bool get canRunInBrowser =>
      browserSupported == true && browserPayloads.hasJavaScript;

  BotCompat copyWith({
    List<String>? desktopRuntimes,
    List<String>? missingDesktopRuntimes,
    bool? browserSupported,
    String? browserReason,
    String? browserRunner,
    BrowserPayloads? browserPayloads,
  }) {
    return BotCompat(
      desktopRuntimes: desktopRuntimes ?? this.desktopRuntimes,
      missingDesktopRuntimes:
          missingDesktopRuntimes ?? this.missingDesktopRuntimes,
      browserSupported: browserSupported ?? this.browserSupported,
      browserReason: browserReason ?? this.browserReason,
      browserRunner: browserRunner ?? this.browserRunner,
      browserPayloads: browserPayloads ?? this.browserPayloads,
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

  BrowserPayloads copyWith({
    BrowserPayload? javascript,
    BrowserPayload? wasm,
    Map<String, dynamic>? metadata,
  }) {
    return BrowserPayloads(
      javascript: javascript ?? this.javascript,
      wasm: wasm ?? this.wasm,
      metadata: metadata ?? this.metadata,
    );
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

  String? decodeUtf8() {
    if (inline != null) {
      return inline;
    }
    if (base64 != null) {
      try {
        return utf8.decode(base64Decode(base64!));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Uint8List? decodeBytes() {
    if (base64 != null) {
      try {
        return Uint8List.fromList(base64Decode(base64!));
      } catch (_) {
        return null;
      }
    }
    if (inline != null) {
      return Uint8List.fromList(utf8.encode(inline!));
    }
    return null;
  }
}
