import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:scriptagher/shared/config/api_base_url.dart';
import '../models/bot.dart';

class BotUploadService {
  BotUploadService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiBaseUrl.resolve();

  final String baseUrl;

  Future<Bot> uploadBotFile({
    required Stream<List<int>> stream,
    required int length,
    required String filename,
  }) async {
    final uri = Uri.parse('$baseUrl/bots/upload');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile('file', stream, length,
        filename: p.basename(filename)));

    final response = await http.Response.fromStream(await request.send());

    if (response.statusCode != 200) {
      final errorBody = response.body.isNotEmpty ? response.body : null;
      throw Exception(
          'Impossibile caricare il bot (${response.statusCode}): ${errorBody ?? 'nessun dettaglio fornito'}');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return Bot.fromJson(data);
  }
}
