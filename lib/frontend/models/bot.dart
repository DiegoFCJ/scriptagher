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
      if (browserDescriptor != null)
        'browser_payload': browserDescriptor!.toEncodedJson(),
    };
  }

  factory Bot.fromMap(Map<String, dynamic> map) {
    final descriptor = _extractBrowserDescriptor(
        map['browser_payload'] ?? map['browser_descriptor']);

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

  factory Bot.fromJson(Map<String, dynamic> json) {
    BrowserBotDescriptor? descriptor;
    final browserPayload =
        json['browser'] ?? json['browser_payload'] ?? json['browser_descriptor'];
    if (browserPayload is Map<String, dynamic>) {
      descriptor = BrowserBotDescriptor.fromJson(browserPayload);
    }
    if (descriptor == null && browserPayload is String) {
      descriptor = _extractBrowserDescriptor(browserPayload);
    }

    return Bot(
      botName: json['bot_name'] ?? json['botName'] ?? '',
      description: json['description'] ?? '',
      startCommand: json['start_command'] ?? json['startCommand'] ?? '',
      sourcePath: json['source_path'] ?? json['sourcePath'] ?? '',
      language: json['language'] ?? '',
      browserDescriptor: descriptor,
    );
  }

  static BrowserBotDescriptor? _extractBrowserDescriptor(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return BrowserBotDescriptor.fromJson(value);
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        return BrowserBotDescriptor.fromEncodedJson(value);
      } catch (_) {
        // Ignore invalid JSON payloads.
      }
    }
    return null;
  }
}
