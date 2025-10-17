import 'dart:convert';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final List<String> tags;
  final String author;
  final String version;

  const Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.tags = const [],
    this.author = '',
    this.version = '',
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
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
      'tags': jsonEncode(tags),
      'author': author,
      'version': version,
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
      'tags': tags,
      'author': author,
      'version': version,
    };
  }

  factory Bot.fromDbMap(Map<String, dynamic> map) {
    return Bot(
      id: map['id'],
      botName: map['bot_name'],
      description: map['description'] ?? '',
      startCommand: map['start_command'] ?? '',
      sourcePath: map['source_path'],
      language: map['language'],
      tags: _decodeTags(map['tags']),
      author: map['author'] ?? '',
      version: map['version'] ?? '',
    );
  }

  factory Bot.fromJson(Map<String, dynamic> json) {
    return Bot(
      id: json['id'],
      botName: json['bot_name'] ?? '',
      description: json['description'] ?? '',
      startCommand: json['start_command'] ?? '',
      sourcePath: json['source_path'] ?? '',
      language: json['language'] ?? '',
      tags: _decodeTags(json['tags']),
      author: json['author'] ?? '',
      version: json['version'] ?? '',
    );
  }

  static List<String> _decodeTags(dynamic rawTags) {
    if (rawTags == null) {
      return const [];
    }

    if (rawTags is String && rawTags.isEmpty) {
      return const [];
    }

    try {
      if (rawTags is String) {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          return decoded.map((tag) => tag.toString()).toList();
        }
        return rawTags
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();
      }

      if (rawTags is List) {
        return rawTags.map((tag) => tag.toString()).toList();
      }
    } catch (_) {
      return rawTags
          .toString()
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }

    return const [];
  }
}
