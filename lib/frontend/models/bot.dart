import 'dart:convert';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final List<String> permissions;
  final String archiveHash;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.permissions = const [],
    this.archiveHash = '',
  });

  Bot copyWith({
    String? description,
    String? startCommand,
    List<String>? permissions,
    String? archiveHash,
  }) {
    return Bot(
      id: id,
      botName: botName,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath,
      language: language,
      permissions: permissions ?? List<String>.from(this.permissions),
      archiveHash: archiveHash ?? this.archiveHash,
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
      'permissions': permissions,
      'archive_hash': archiveHash,
    };
  }

  factory Bot.fromMap(Map<String, dynamic> map) {
    final rawPermissions = map['permissions'];
    List<String> permissions = [];
    if (rawPermissions is String && rawPermissions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPermissions);
        if (decoded is List) {
          permissions = decoded.whereType<String>().toList();
        }
      } catch (_) {
        permissions = [];
      }
    } else if (rawPermissions is List) {
      permissions = rawPermissions.whereType<String>().toList();
    }

    return Bot(
      id: map['id'],
      botName: map['bot_name'],
      description: map['description'] ?? '',
      startCommand: map['start_command'] ?? '',
      sourcePath: map['source_path'],
      language: map['language'],
      permissions: permissions,
      archiveHash: map['archive_hash']?.toString() ?? '',
    );
  }

  factory Bot.fromJson(Map<String, dynamic> json) {
    final permissionsRaw = json['permissions'];
    List<String> permissions = [];
    if (permissionsRaw is List) {
      permissions = permissionsRaw.whereType<String>().toList();
    }

    return Bot(
      botName: json['bot_name'] ?? '',
      description: json['description'] ?? '',
      startCommand: json['start_command'] ?? '',
      sourcePath: json['source_path'] ?? '',
      language: json['language'] ?? '',
      permissions: permissions,
      archiveHash: json['archive_hash']?.toString() ?? '',
    );
  }
}
