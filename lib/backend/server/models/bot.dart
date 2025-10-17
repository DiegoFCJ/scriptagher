class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final String hash;
  final List<String> permissions;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.hash = '',
    List<String>? permissions,
  }) : permissions = permissions ?? const [];

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
    String? hash,
    List<String>? permissions,
  }) {
    return Bot(
      id: id,
      botName: botName,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath,
      language: language,
      hash: hash ?? this.hash,
      permissions: permissions ?? this.permissions,
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
      'hash': hash,
      'permissions': permissions.isEmpty ? null : permissions.join(','),
    };
  }

  Map<String, dynamic> toApiMap() {
    return {
      'id': id,
      'bot_name': botName,
      'description': description,
      'start_command': startCommand,
      'source_path': sourcePath,
      'language': language,
      'hash': hash,
      'permissions': List<String>.from(permissions),
    };
  }

  factory Bot.fromMap(Map<String, dynamic> map) {
    final rawPermissions = map['permissions'];
    List<String> parsedPermissions = [];
    if (rawPermissions is String && rawPermissions.isNotEmpty) {
      parsedPermissions = rawPermissions.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawPermissions is List) {
      parsedPermissions = rawPermissions.map((e) => e.toString()).toList();
    }

    return Bot(
      id: map['id'],
      botName: map['bot_name'],
      description: map['description'] ?? '',
      startCommand: map['start_command'] ?? '',
      sourcePath: map['source_path'],
      language: map['language'],
      hash: map['hash'] ?? '',
      permissions: parsedPermissions,
    );
  }
}
