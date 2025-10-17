class BotUploadException implements Exception {
  BotUploadException(this.message, {this.statusCode = 400});

  final String message;
  final int statusCode;

  @override
  String toString() => 'BotUploadException: $message';
}
