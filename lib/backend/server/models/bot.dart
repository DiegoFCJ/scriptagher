import 'dart:convert';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final BotCompatibility? compat;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.compat,
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
    BotCompatibility? compat,
  }) {
    return Bot(
      id: id,
      botName: botName,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath,
      language: language,
      compat: compat ?? this.compat,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bot_name': botName,
      'description': description,
      'start_command': startCommand,
      'source_path': sourcePath,
      'language': language,
      'compat': compat?.toJson(),
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'bot_name': botName,
      'description': description,
      'start_command': startCommand,
      'source_path': sourcePath,
      'language': language,
      'compat': compat != null ? jsonEncode(compat!.toJson()) : null,
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
      compat: BotCompatibility.fromDynamic(map['compat']),
    );
  }
}

class BotCompatibility {
  final DesktopCompatibility? desktop;
  final BrowserCompatibility? browser;

  BotCompatibility({this.desktop, this.browser});

  BotCompatibility copyWith({
    DesktopCompatibility? desktop,
    BrowserCompatibility? browser,
  }) {
    return BotCompatibility(
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

  static BotCompatibility? fromDynamic(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is String && data.trim().isEmpty) {
      return null;
    }

    Map<String, dynamic>? json;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded == null) {
          return null;
        }
        json = Map<String, dynamic>.from(decoded as Map);
      } catch (_) {
        return null;
      }
    } else if (data is Map<String, dynamic>) {
      json = data;
    } else {
      return null;
    }

    return BotCompatibility(
      desktop: json!['desktop'] != null
          ? DesktopCompatibility.fromJson(
              Map<String, dynamic>.from(json['desktop']))
          : null,
      browser: json['browser'] != null
          ? BrowserCompatibility.fromJson(
              Map<String, dynamic>.from(json['browser']))
          : null,
    );
  }
}

class DesktopCompatibility {
  final bool? supported;
  final String? runner;
  final List<String> runnerArgs;
  final bool? runnerAvailable;
  final String? runnerVersion;
  final String? runnerError;

  DesktopCompatibility({
    this.supported,
    this.runner,
    List<String>? runnerArgs,
    this.runnerAvailable,
    this.runnerVersion,
    this.runnerError,
  }) : runnerArgs = runnerArgs ?? const ['--version'];

  DesktopCompatibility copyWith({
    bool? supported,
    String? runner,
    List<String>? runnerArgs,
    bool? runnerAvailable,
    String? runnerVersion,
    String? runnerError,
  }) {
    return DesktopCompatibility(
      supported: supported ?? this.supported,
      runner: runner ?? this.runner,
      runnerArgs: runnerArgs ?? this.runnerArgs,
      runnerAvailable: runnerAvailable ?? this.runnerAvailable,
      runnerVersion: runnerVersion ?? this.runnerVersion,
      runnerError: runnerError ?? this.runnerError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (supported != null) 'supported': supported,
      if (runner != null) 'runner': runner,
      if (runnerArgs.isNotEmpty) 'runnerArgs': runnerArgs,
      if (runnerAvailable != null) 'runnerAvailable': runnerAvailable,
      if (runnerVersion != null) 'runnerVersion': runnerVersion,
      if (runnerError != null) 'runnerError': runnerError,
    };
  }

  factory DesktopCompatibility.fromJson(Map<String, dynamic> json) {
    final args = json['runnerArgs'];
    return DesktopCompatibility(
      supported: json['supported'],
      runner: json['runner'],
      runnerArgs: args != null
          ? List<String>.from(args.map((arg) => arg.toString()))
          : null,
      runnerAvailable: json['runnerAvailable'],
      runnerVersion: json['runnerVersion'],
      runnerError: json['runnerError'],
    );
  }
}

class BrowserCompatibility {
  final bool supported;
  final String? reason;

  BrowserCompatibility({required this.supported, this.reason});

  Map<String, dynamic> toJson() {
    return {
      'supported': supported,
      if (reason != null) 'reason': reason,
    };
  }

  factory BrowserCompatibility.fromJson(Map<String, dynamic> json) {
    return BrowserCompatibility(
      supported: json['supported'] ?? true,
      reason: json['reason'],
    );
  }
}
