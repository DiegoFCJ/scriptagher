import 'dart:convert';
import 'dart:io';

import '../models/bot.dart';

class ExecutionLogMetadata {
  ExecutionLogMetadata({
    required this.runId,
    required this.language,
    required this.botName,
    required this.startedAt,
    required this.logFileName,
    this.botId,
    this.finishedAt,
    this.exitCode,
    this.logFileSize,
    this.errorMessage,
  });

  final String runId;
  final String language;
  final String botName;
  final DateTime startedAt;
  final int? botId;
  DateTime? finishedAt;
  int? exitCode;
  final String logFileName;
  int? logFileSize;
  String? errorMessage;

  Map<String, dynamic> toJson() {
    return {
      'run_id': runId,
      'language': language,
      'bot_name': botName,
      'bot_id': botId,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'exit_code': exitCode,
      'log_file': logFileName,
      'log_file_size': logFileSize,
      'error': errorMessage,
    };
  }

  Map<String, dynamic> toLogMetadata({String? entryType}) {
    return {
      'runId': runId,
      'botId': botId,
      'language': language,
      'botName': botName,
      'startedAt': startedAt.toIso8601String(),
      if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
      if (exitCode != null) 'exitCode': exitCode,
      if (entryType != null) 'entryType': entryType,
    };
  }

  static ExecutionLogMetadata fromJson(Map<String, dynamic> json) {
    return ExecutionLogMetadata(
      runId: json['run_id'] as String,
      language: json['language'] as String,
      botName: json['bot_name'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      logFileName: json['log_file'] as String,
      botId: json['bot_id'] as int?,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String)
          : null,
      exitCode: json['exit_code'] as int?,
      logFileSize: json['log_file_size'] as int?,
      errorMessage: json['error'] as String?,
    );
  }
}

class ExecutionLogSession {
  ExecutionLogSession({
    required this.metadata,
    required this.logFile,
    required this.metadataFile,
    required this.logSink,
  });

  final ExecutionLogMetadata metadata;
  final File logFile;
  final File metadataFile;
  final IOSink logSink;

  Future<void> dispose() async {
    await logSink.flush();
    await logSink.close();
  }
}

class ExecutionLogManager {
  ExecutionLogManager({Directory? baseDirectory})
      : _baseDirectory = baseDirectory ?? Directory('logs/executions');

  final Directory _baseDirectory;

  Future<ExecutionLogSession> startSession(Bot bot) async {
    final runId = _generateRunId();
    final directory = await _prepareDirectory(bot.language, bot.botName);
    final logFile = File('${directory.path}/run_$runId.log');
    final metadataFile = File('${directory.path}/run_$runId.json');

    final metadata = ExecutionLogMetadata(
      runId: runId,
      language: bot.language,
      botName: bot.botName,
      botId: bot.id,
      startedAt: DateTime.now().toUtc(),
      logFileName: logFile.uri.pathSegments.last,
    );

    await metadataFile.writeAsString(jsonEncode(metadata.toJson()));
    final sink = logFile.openWrite(mode: FileMode.append);

    return ExecutionLogSession(
      metadata: metadata,
      logFile: logFile,
      metadataFile: metadataFile,
      logSink: sink,
    );
  }

  Future<void> finalizeSession(
    ExecutionLogSession session, {
    required int exitCode,
    String? errorMessage,
  }) async {
    await session.logSink.flush();
    session.metadata
      ..exitCode = exitCode
      ..finishedAt = DateTime.now().toUtc()
      ..errorMessage = errorMessage
      ..logFileSize = await session.logFile.length();

    await session.metadataFile
        .writeAsString(jsonEncode(session.metadata.toJson()));
  }

  Future<List<ExecutionLogMetadata>> listLogs(
      String language, String botName) async {
    final directory = Directory('${_baseDirectory.path}/$language/$botName');
    if (!await directory.exists()) {
      return [];
    }

    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final logs = <ExecutionLogMetadata>[];
    for (final file in files) {
      try {
        final contents = await file.readAsString();
        final jsonData = jsonDecode(contents) as Map<String, dynamic>;
        logs.add(ExecutionLogMetadata.fromJson(jsonData));
      } catch (_) {
        continue;
      }
    }

    logs.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return logs;
  }

  Future<ExecutionLogMetadata?> loadMetadata(
      String language, String botName, String runId) async {
    final file = await _metadataFile(language, botName, runId);
    if (file == null || !await file.exists()) {
      return null;
    }
    try {
      final contents = await file.readAsString();
      final jsonData = jsonDecode(contents) as Map<String, dynamic>;
      return ExecutionLogMetadata.fromJson(jsonData);
    } catch (_) {
      return null;
    }
  }

  Future<File?> openLogFile(
      String language, String botName, String logFileName) async {
    final directory = Directory('${_baseDirectory.path}/$language/$botName');
    final file = File('${directory.path}/$logFileName');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<Directory> _prepareDirectory(String language, String botName) async {
    final directory = Directory('${_baseDirectory.path}/$language/$botName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File?> _metadataFile(
      String language, String botName, String runId) async {
    final directory = Directory('${_baseDirectory.path}/$language/$botName');
    if (!await directory.exists()) {
      return null;
    }
    final file = File('${directory.path}/run_$runId.json');
    return file;
  }

  String _generateRunId() {
    final now = DateTime.now().toUtc();
    return now.toIso8601String().replaceAll(':', '-');
  }
}
