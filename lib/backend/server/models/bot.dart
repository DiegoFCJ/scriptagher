class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final String origin;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    required this.origin,
  });

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
    String? origin,
  }) {
    return Bot(
      id: id,
      botName: botName,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath,
      language: language,
      origin: origin ?? this.origin,
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
      'origin': origin,
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
      origin: map['origin'] ?? 'Remoto',
    );
  }
}
