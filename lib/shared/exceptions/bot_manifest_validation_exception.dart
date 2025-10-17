class BotManifestValidationException implements Exception {
  final String message;

  BotManifestValidationException(this.message);

  @override
  String toString() => 'BotManifestValidationException: $message';
}
