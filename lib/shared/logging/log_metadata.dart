import 'package:intl/intl.dart';

/// Metadata attached to a bot execution log.
class LogMetadata {
  /// Identifier of the bot. When an integer [botId] is not available the
  /// bot's name should be used.
  final String botId;

  /// Timestamp representing when the execution started.
  final DateTime startTime;

  /// Optional exit code produced by the execution.
  final int? exitCode;

  /// Optional timestamp that marks when the execution finished.
  final DateTime? endTime;

  const LogMetadata({
    required this.botId,
    required this.startTime,
    this.exitCode,
    this.endTime,
  });

  /// Creates a copy of the metadata adding optional information.
  LogMetadata copyWith({
    int? exitCode,
    DateTime? endTime,
  }) {
    return LogMetadata(
      botId: botId,
      startTime: startTime,
      exitCode: exitCode ?? this.exitCode,
      endTime: endTime ?? this.endTime,
    );
  }

  /// Sanitises the identifier so that it can be used safely as a directory or
  /// file name component.
  static String sanitizeIdentifier(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return sanitized.isEmpty ? 'bot' : sanitized;
  }

  /// Identifier that is safe to be used for directory names.
  String get sanitizedBotId => sanitizeIdentifier(botId);

  /// Unique identifier for this execution run.
  String get runId => DateFormat('yyyyMMdd_HHmmss').format(startTime);

  /// File name that should be used for the log file associated with this run.
  String get fileName => '${sanitizedBotId}_$runId.log';

  /// Formats the metadata as a suffix for textual log messages.
  String describe() {
    final buffer = StringBuffer('[botId:$botId][runId:$runId]');
    if (exitCode != null) {
      buffer.write('[exitCode:$exitCode]');
    }
    if (endTime != null) {
      buffer.write('[ended:${DateFormat('yyyy-MM-dd HH:mm:ss').format(endTime!)}]');
    }
    return buffer.toString();
  }

  /// Returns a header suitable to be written at the top of the run log file.
  String buildHeader() {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final buffer = StringBuffer()
      ..writeln('Bot ID: $botId')
      ..writeln('Run ID: $runId')
      ..writeln('Started: ${formatter.format(startTime)}')
      ..writeln('');
    return buffer.toString();
  }

  /// Returns the summary section that should be appended once the execution
  /// completes.
  String buildCompletionSection() {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final buffer = StringBuffer();
    if (endTime != null) {
      buffer.writeln('Finished: ${formatter.format(endTime!)}');
    }
    if (exitCode != null) {
      buffer.writeln('Exit code: $exitCode');
    }
    buffer.writeln('');
    return buffer.toString();
  }
}
