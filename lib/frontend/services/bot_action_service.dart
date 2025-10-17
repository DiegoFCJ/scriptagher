import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:scriptagher/shared/constants/APIS.dart';

import '../models/bot.dart';

class BotActionService {
  final String baseUrl;
  final http.Client _client;

  BotActionService({this.baseUrl = 'http://localhost:8080', http.Client? client})
      : _client = client ?? http.Client();

  Future<Bot> downloadBot(String language, String botName) async {
    final url = Uri.parse('$baseUrl/bots/$language/$botName');
    final response = await _client.get(url);

    if (response.statusCode != 200) {
      throw HttpException(
          'Impossibile completare il download (status ${response.statusCode}).');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return Bot.fromJson(data);
  }

  Future<void> openBotFolder(Bot bot) async {
    final folderPath =
        '${APIS.BOT_DIR_DATA_REMOTE}/${bot.language}/${bot.botName}';
    final directory = Directory(folderPath);

    if (!await directory.exists()) {
      throw FileSystemException('Cartella non trovata', folderPath);
    }

    if (Platform.isMacOS) {
      await Process.run('open', [directory.path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [directory.path.replaceAll('/', '\\')]);
    } else {
      await Process.run('xdg-open', [directory.path]);
    }
  }

  Future<void> runBot(Bot bot) async {
    final command = bot.startCommand.trim();
    if (command.isEmpty) {
      throw const FormatException('Nessun comando di avvio disponibile.');
    }

    if (Platform.isWindows) {
      await Process.start('cmd.exe', ['/c', command],
          workingDirectory: Directory.current.path);
    } else {
      await Process.start('/bin/sh', ['-c', command],
          workingDirectory: Directory.current.path);
    }
  }
}
