import 'dart:convert';
import 'dart:typed_data';

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
  final String version;
  final String? author;
  final List<String> tags;

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
    this.version = '',
    this.author,
    this.tags = const [],
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
    BotCompat? compat,
    List<String>? permissions,
    String? archiveSha256,
    String? version,
    String? author,
    List<String>? tags,
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
      version: version ?? this.version,
      author: author ?? this.author,
      tags: tags ?? this.tags,
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
      'compat': compat.toJson(),
      'permissions': permissions,
      'archive_sha256': archiveSha256,
      'version': version,
      'author': author,
      'tags': tags,
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
      compat: BotCompat.fromJson(map['compat']),
      permissions:
          (map['permissions'] as List?)?.whereType<String>().toList() ?? const [],
      archiveSha256: map['archive_sha256'] as String?,
      version: map['version']?.toString() ?? '',
      author: map['author']?.toString(),
      tags: (map['tags'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  factory Bot.fromJson(Map<String, dynamic> json) {
    final dynamic idValue = json['id'];
    int? parsedId;
    if (idValue is int) {
      parsedId = idValue;
    } else if (idValue is String) {
      parsedId = int.tryParse(idValue);
    }

    return Bot(
      id: parsedId,
      botName: json['bot_name'] ?? '',
      description: json['description'] ?? '',
      startCommand: json['start_command'] ?? '',
      sourcePath: json['source_path'] ?? '',
      language: json['language'] ?? '',
      compat: BotCompat.fromJson(json['compat']),
      permissions:
          (json['permissions'] as List?)?.whereType<String>().toList() ?? const [],
      archiveSha256: json['archive_sha256'] as String?,
      version: json['version']?.toString() ?? '',
      author: json['author']?.toString(),
      tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'bot_name': botName,
        'description': description,
        'start_command': startCommand,
        'source_path': sourcePath,
        'language': language,
        'compat': compat.toJson(),
        'permissions': permissions,
        if (archiveSha256 != null) 'archive_sha256': archiveSha256,
        'version': version,
        if (author != null) 'author': author,
        'tags': tags,
      };

  bool get isDownloaded =>
      sourcePath.contains('data/remote') || sourcePath.contains('data\\remote');

  bool get isLocal =>
      sourcePath.contains('data/local') || sourcePath.contains('data\\local');
}

class BotCompat {
  final List<String> desktopRuntimes;
  final List<String> missingDesktopRuntimes;
  final bool? browserSupported;
  final String? browserReason;
  final String? browserRunner;
  final BrowserPayloads browserPayloads;
  final MobileCompat mobile;

  const BotCompat({
    this.desktopRuntimes = const [],
    this.missingDesktopRuntimes = const [],
    this.browserSupported,
    this.browserReason,
    this.browserRunner,
    this.browserPayloads = const BrowserPayloads(),
    this.mobile = const MobileCompat(),
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
  bool get hasMobileSupport => mobile.isSupported;

  BotCompat copyWith({
    List<String>? desktopRuntimes,
    List<String>? missingDesktopRuntimes,
    bool? browserSupported,
    String? browserReason,
    String? browserRunner,
    BrowserPayloads? browserPayloads,
    MobileCompat? mobile,
  }) {
    return BotCompat(
      desktopRuntimes: desktopRuntimes ?? this.desktopRuntimes,
      missingDesktopRuntimes:
          missingDesktopRuntimes ?? this.missingDesktopRuntimes,
      browserSupported: browserSupported ?? this.browserSupported,
      browserReason: browserReason ?? this.browserReason,
      browserRunner: browserRunner ?? this.browserRunner,
      browserPayloads: browserPayloads ?? this.browserPayloads,
      mobile: mobile ?? this.mobile,
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
      if (!mobile.isEmpty) 'mobile': mobile.toJson(),
    };
  }

  factory BotCompat.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const BotCompat();
    }

    final desktop = json['desktop'];
    final browser = json['browser'];
    final mobileJson = json['mobile'];

    List<String> runtimes = const [];
    List<String> missing = const [];
    bool? browserSupported;
    String? browserReason;
    String? browserRunner;
    BrowserPayloads payloads = const BrowserPayloads();
    MobileCompat mobile = const MobileCompat();

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

    if (mobileJson != null) {
      mobile = MobileCompat.fromJson(mobileJson);
    }

    return BotCompat(
      desktopRuntimes: runtimes,
      missingDesktopRuntimes: missing,
      browserSupported: browserSupported,
      browserReason: browserReason,
      browserRunner: browserRunner,
      browserPayloads: payloads,
      mobile: mobile,
    );
  }
}

class MobileCompat {
  const MobileCompat({
    this.supported,
    this.platforms = const [],
    this.reason,
  });

  final bool? supported;
  final List<String> platforms;
  final String? reason;

  bool get isSupported => supported == true;
  bool get isUnsupported => supported == false;
  bool get isUnknown => supported == null && platforms.isEmpty && reason == null;
  bool get isEmpty => isUnknown;

  bool supportsPlatform(String platform) {
    if (!isSupported) {
      return false;
    }
    if (platforms.isEmpty) {
      return true;
    }
    final normalized = platform.toLowerCase();
    return platforms.map((p) => p.toLowerCase()).any((entry) {
      if (entry == normalized) {
        return true;
      }
      if (entry == 'mobile') {
        return true;
      }
      if (entry == 'ios' && normalized == 'ios') {
        return true;
      }
      if (entry == 'android' && normalized == 'android') {
        return true;
      }
      return false;
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'supported': supported,
      if (platforms.isNotEmpty) 'platforms': platforms,
      if (reason != null) 'reason': reason,
    };
  }

  MobileCompat copyWith({
    bool? supported,
    List<String>? platforms,
    String? reason,
  }) {
    return MobileCompat(
      supported: supported ?? this.supported,
      platforms: platforms ?? this.platforms,
      reason: reason ?? this.reason,
    );
  }

  static MobileCompat fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      if (json is bool) {
        return MobileCompat(supported: json);
      }
      return const MobileCompat();
    }

    final supported = json['supported'];
    final reason = json['reason'];
    List<String> platforms = const [];
    final platformsJson = json['platforms'] ?? json['devices'];
    if (platformsJson is List) {
      platforms = platformsJson.whereType<String>().toList();
    }

    return MobileCompat(
      supported: supported is bool ? supported : null,
      platforms: platforms,
      reason: reason is String ? reason : null,
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
