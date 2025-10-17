import 'package:scriptagher/shared/models/browser_bot_descriptor.dart';

class Bot {
  final int? id;
  final String botName;
  final String description;
  final String startCommand;
  final String sourcePath;
  final String language;
  final BrowserBotDescriptor? browserDescriptor;

  bool get isBrowserCompatible =>
      browserDescriptor != null && browserDescriptor!.compatible;

  const Bot({
    this.id,
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.sourcePath,
    required this.language,
    this.browserDescriptor,
  });

  Bot copyWith({
    String? description,
    String? startCommand,
    BrowserBotDescriptor? browserDescriptor,
  }) {
    return Bot(
      id: id,
      botName: botName,
      description: description ?? this.description,
      startCommand: startCommand ?? this.startCommand,
      sourcePath: sourcePath,
      language: language,
      browserDescriptor: browserDescriptor ?? this.browserDescriptor,
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
      'browser_compatible': isBrowserCompatible ? 1 : 0,
      'browser_payload':
          browserDescriptor != null ? browserDescriptor!.toEncodedJson() : null,
    };
  }

  factory Bot.fromMap(Map<String, dynamic> map) {
    final payloadRaw = map['browser_payload'];
    BrowserBotDescriptor? descriptor;

    if (payloadRaw is String && payloadRaw.isNotEmpty) {
      try {
        descriptor = BrowserBotDescriptor.fromEncodedJson(payloadRaw);
      } catch (_) {
        descriptor = null;
      }
    } else if (payloadRaw is Map<String, dynamic>) {
      descriptor = BrowserBotDescriptor.fromJson(payloadRaw);
    }

    return Bot(
      id: map['id'],
      botName: map['bot_name'],
      description: map['description'] ?? '',
      startCommand: map['start_command'] ?? '',
      sourcePath: map['source_path'],
      language: map['language'],
      browserDescriptor: descriptor,
    );
  }
}
