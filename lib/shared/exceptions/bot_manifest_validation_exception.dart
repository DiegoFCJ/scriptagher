class BotManifestValidationException implements Exception {
  final List<String> missingFields;
  final Map<String, String> invalidFields;

  BotManifestValidationException({
    List<String>? missingFields,
    Map<String, String>? invalidFields,
  })  : missingFields = List.unmodifiable(missingFields ?? const []),
        invalidFields = Map.unmodifiable(invalidFields ?? const {});

  String get message {
    final buffer = StringBuffer('Bot manifest validation failed');

    if (missingFields.isNotEmpty) {
      buffer.write(
          ": missing required field${missingFields.length > 1 ? 's' : ''} "
          "${missingFields.join(', ')}");
    }

    if (invalidFields.isNotEmpty) {
      if (missingFields.isNotEmpty) {
        buffer.write('; ');
      } else {
        buffer.write(': ');
      }
      final descriptions = invalidFields.entries
          .map((entry) => "${entry.key} (${entry.value})")
          .join(', ');
      buffer.write('invalid field values -> $descriptions');
    }

    return buffer.toString();
  }

  @override
  String toString() => 'BotManifestValidationException: $message';
}
