class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
  }) {
    return Bot(
      id: id,
      botName: botName,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath,
      language: language,
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
    );
  }

  factory Bot.fromJson(Map<String, dynamic> json) {
    return Bot(
      botName: json['bot_name'] ?? '',
      description: json['description'] ?? '',
      startCommand: json['start_command'] ?? '',
      sourcePath: json['source_path'] ?? '',
      language: json['language'] ?? '',
    );
  }
}
