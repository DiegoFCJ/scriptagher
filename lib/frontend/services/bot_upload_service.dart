import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/bot.dart';

class BotUploadService {
  BotUploadService({this.baseUrl = 'http://localhost:8080'});

  final String baseUrl;

  Future<Bot> uploadZip(File file) async {
    return _sendFile(file);
  }

  Future<Bot> uploadDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      throw Exception('Directory non trovata: $directoryPath');
    }

    final tempDir = await Directory.systemTemp.createTemp('bot_upload_');
    final zipPath = p.join(tempDir.path, '${p.basename(directory.path)}.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    encoder.addDirectory(directory, includeDirName: true);
    encoder.close();

    final zipFile = File(zipPath);
    try {
      final bot = await _sendFile(zipFile);
      return bot;
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<Bot> _sendFile(File file) async {
    final uri = Uri.parse('$baseUrl/bots/upload');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      return Bot.fromJson(data);
    } else {
      String message = 'Upload fallito (status ${streamedResponse.statusCode})';
      try {
        final error = jsonDecode(responseBody);
        if (error is Map && error['error'] is String) {
          message = error['error'] as String;
        }
      } catch (_) {
        // Ignore parse errors.
      }
      throw Exception(message);
    }
  }
}
