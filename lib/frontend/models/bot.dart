import 'package:scriptagher/shared/models/compat.dart';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final CompatInfo compat;

  Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    CompatInfo? compat,
  }) : compat = compat ?? CompatInfo.empty();

  // Metodo factory per creare una nuova versione di Bot con dettagli aggiornati
  Bot copyWith({
    String? description,
    String? startCommand,
    CompatInfo? compat,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bot_name': botName,
      'description': description,
      'start_command': startCommand,
      'source_path': sourcePath,
      'language': language,
      'compat': compat.toJson(),
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
      compat: CompatInfo.fromJson(map['compat']),
    );
  }

  factory Bot.fromJson(Map<String, dynamic> json) {
    return Bot(
      id: json['id'],
      botName: json['bot_name'] ?? json['botName'] ?? '',
      description: json['description']?.toString() ?? '',
      startCommand: json['start_command']?.toString() ?? '',
      sourcePath: json['source_path']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      compat: CompatInfo.fromJson(json['compat']),
    );
  }
}
