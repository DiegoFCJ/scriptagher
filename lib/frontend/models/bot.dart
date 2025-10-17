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

  factory Bot.fromJson(Map<String, dynamic> json) {
    return Bot(
      id: json['id'],
      botName: json['bot_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      startCommand: json['start_command']?.toString() ?? '',
      sourcePath: json['source_path']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      tags: _parseTags(json['tags']),
      author: json['author']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
    );
  }

  static List<String> _parseTags(dynamic rawTags) {
    if (rawTags == null) return const [];
    if (rawTags is List) {
      return rawTags.map((tag) => tag.toString()).toList();
    }
    if (rawTags is String && rawTags.isNotEmpty) {
      return rawTags
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
