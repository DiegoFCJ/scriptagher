import 'dart:io';

import 'package:scriptagher/backend/server/models/bot.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/custom_logger.dart';

class ExecutionService {
  ExecutionService();

  final CustomLogger _logger = CustomLogger();

  Future<int> startBot(Bot bot) async {
    try {
      _logger.info(
        LOGS.EXECUTION_SERVICE,
        'Starting bot ${bot.botName} with language ${bot.language}',
      );

      final process = await _startProcess(bot);

      _logger.info(
        LOGS.EXECUTION_SERVICE,
        'Started process with pid ${process.pid} for bot ${bot.botName}',
      );

      return process.pid;
    } on UnsupportedError catch (e) {
      _logger.error(LOGS.EXECUTION_SERVICE, e.message ?? e.toString());
      rethrow;
    } catch (e) {
      _logger.error(
          LOGS.EXECUTION_SERVICE, 'Error starting bot ${bot.botName}: $e');
      rethrow;
    }
  }

  Future<Process> _startProcess(Bot bot) {
    final language = bot.language.toLowerCase().trim();
    final command = bot.startCommand.trim().isNotEmpty
        ? bot.startCommand.trim()
        : bot.sourcePath.trim();

    if (command.isEmpty) {
      throw UnsupportedError('Missing start command for bot ${bot.botName}');
    }

    switch (language) {
      case 'node':
      case 'javascript':
        return _startNodeProcess(bot.botName, command);
      case 'python':
      case 'python3':
        return _startPythonProcess(bot.botName, command);
      case 'bash':
      case 'shell':
      case 'sh':
        return Process.start('bash', ['-c', command]);
      default:
        throw UnsupportedError('Unsupported language: ${bot.language}');
    }
  }

  Future<Process> _startNodeProcess(String botName, String command) {
    final tokens = _splitCommand(command);
    if (tokens.isEmpty) {
      throw UnsupportedError('Missing start command for bot $botName');
    }

    final first = tokens.first.toLowerCase();
    if (first == 'npm' || first == 'yarn' || first == 'pnpm') {
      return Process.start('bash', ['-c', command]);
    }

    if (first == 'node') {
      tokens.removeAt(0);
    }

    if (tokens.isEmpty) {
      throw UnsupportedError('Missing Node script for bot $botName');
    }

    return Process.start('node', tokens);
  }

  Future<Process> _startPythonProcess(String botName, String command) {
    final tokens = _splitCommand(command);
    if (tokens.isEmpty) {
      throw UnsupportedError('Missing start command for bot $botName');
    }

    final first = tokens.first.toLowerCase();
    if (first == 'python' || first == 'python3' || first == 'python2') {
      tokens.removeAt(0);
    }

    if (tokens.isEmpty) {
      throw UnsupportedError('Missing Python script for bot $botName');
    }

    return Process.start('python3', tokens);
  }

  List<String> _splitCommand(String command) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inSingleQuotes = false;
    bool inDoubleQuotes = false;

    for (int i = 0; i < command.length; i++) {
      final char = command[i];

      if (char == "'" && !inDoubleQuotes) {
        inSingleQuotes = !inSingleQuotes;
        continue;
      }

      if (char == '"' && !inSingleQuotes) {
        inDoubleQuotes = !inDoubleQuotes;
        continue;
      }

      if (char == '\\' && i + 1 < command.length) {
        i++;
        buffer.write(command[i]);
        continue;
      }

      if (char.trim().isEmpty && !inSingleQuotes && !inDoubleQuotes) {
        if (buffer.isNotEmpty) {
          result.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      buffer.write(char);
    }

    if (buffer.isNotEmpty) {
      result.add(buffer.toString());
    }

    return result;
  }
}
