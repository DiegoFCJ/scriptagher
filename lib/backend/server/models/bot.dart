import 'dart:convert';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final String author;
  final String version;
  final List<String> permissions;
  final List<String> platformCompatibility;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.author = '',
    this.version = '',
    List<String>? permissions,
    List<String>? platformCompatibility,
  })  : permissions = permissions ?? const [],
        platformCompatibility = platformCompatibility ?? const [];

  Bot copyWith({
    String? description,
    String? startCommand,
    String? author,
    String? version,
    List<String>? permissions,
    List<String>? platformCompatibility,
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
      permissions: permissions ?? this.permissions,
      platformCompatibility:
          platformCompatibility ?? this.platformCompatibility,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'bot_name': botName,
      'description': description,
      'start_command': startCommand,
      'source_path': sourcePath,
      'language': language,
      'author': author,
      'version': version,
      'permissions': jsonEncode(permissions),
      'platform_compatibility': jsonEncode(platformCompatibility),
    };
  }

  Map<String, dynamic> toJson() {
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
      'platform_compatibility': platformCompatibility,
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
      author: map['author'] ?? '',
      version: map['version'] ?? '',
      permissions: _decodeList(map['permissions']),
      platformCompatibility:
          _decodeList(map['platform_compatibility']),
    );
  }

  static List<String> _decodeList(dynamic value) {
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }
    return const [];
  }
}
