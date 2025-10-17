import 'package:intl/intl.dart';

class ExecutionLog {
  ExecutionLog({
    required this.runId,
    required this.startedAt,
    required this.logFileName,
    this.botId,
    this.language,
    this.botName,
    this.finishedAt,
    this.exitCode,
    this.logFileSize,
    this.errorMessage,
  });

  final String runId;
  final DateTime startedAt;
  final String logFileName;
  final int? botId;
  final String? language;
  final String? botName;
  final DateTime? finishedAt;
  final int? exitCode;
  final int? logFileSize;
  final String? errorMessage;

  factory ExecutionLog.fromJson(Map<String, dynamic> json) {
    return ExecutionLog(
      runId: json['run_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      logFileName: json['log_file'] as String,
      botId: json['bot_id'] as int?,
      language: json['language'] as String?,
      botName: json['bot_name'] as String?,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String)
          : null,
      exitCode: json['exit_code'] as int?,
      logFileSize: json['log_file_size'] as int?,
      errorMessage: json['error'] as String?,
    );
  }

  String get formattedStartedAt =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(startedAt.toLocal());

  String get formattedFinishedAt => finishedAt == null
      ? '—'
      : DateFormat('yyyy-MM-dd HH:mm:ss').format(finishedAt!.toLocal());

  String get status {
    if (exitCode == null) {
      return 'In corso';
    }
    return exitCode == 0 ? 'Completato' : 'Terminato con errori';
  }

  String get formattedSize {
    if (logFileSize == null) {
      return 'N/D';
    }
    if (logFileSize! < 1024) {
      return '${logFileSize!} B';
    }
    if (logFileSize! < 1024 * 1024) {
      return '${(logFileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(logFileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
