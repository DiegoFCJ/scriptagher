import 'package:scriptagher/shared/constants/permissions.dart';

class BotManifest {
  final String botName;
  final String description;
  final String startCommand;
  final String hash;
  final List<String> permissions;

  BotManifest({
    required this.botName,
    required this.description,
    required this.startCommand,
    required this.hash,
    required List<String> permissions,
  }) : permissions = List.unmodifiable(permissions);

  factory BotManifest.fromJson(Map<String, dynamic> json) {
    final botName = _readString(json, 'botName');
    final description = _readString(json, 'description');
    final startCommand = _readString(json, 'startCommand');
    final hash = _readString(json, 'hash');

    if (!_sha256Regex.hasMatch(hash)) {
      throw const FormatException('Campo hash non valido: deve essere uno SHA-256 esadecimale a 64 caratteri.');
    }

    final permissions = _parsePermissions(json['permissions']);

    return BotManifest(
      botName: botName,
      description: description,
      startCommand: startCommand,
      hash: hash.toLowerCase(),
      permissions: permissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'botName': botName,
      'description': description,
      'startCommand': startCommand,
      'hash': hash,
      'permissions': permissions,
    };
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    throw FormatException('Campo mancante o non valido: $key');
  }

  static List<String> _parsePermissions(dynamic raw) {
    if (raw == null) {
      return const [];
    }

    if (raw is! List) {
      throw const FormatException('Il campo permissions deve essere una lista.');
    }

    final permissions = <String>{};
    for (final entry in raw) {
      if (entry is! String || entry.trim().isEmpty) {
        throw const FormatException('Ogni permesso deve essere una stringa non vuota.');
      }
      final normalized = entry.trim();
      if (!BotPermissions.allowed.contains(normalized)) {
        throw FormatException('Permesso sconosciuto richiesto: $normalized');
      }
      permissions.add(normalized);
    }

    final sorted = permissions.toList()..sort();
    return sorted;
  }

  static final RegExp _sha256Regex = RegExp(r'^[a-fA-F0-9]{64}$');
}
