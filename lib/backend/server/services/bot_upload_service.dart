import 'dart:async';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';
import 'package:scriptagher/shared/utils/ZipUtils.dart';

import '../db/bot_database.dart';
import '../exceptions/bot_upload_exception.dart';
import '../models/bot.dart';

class BotUploadService {
  BotUploadService(this._botDatabase);

  final BotDatabase _botDatabase;
  final CustomLogger logger = CustomLogger();

  Future<Bot> handleUpload(Request request) async {
    logger.info(LOGS.BOT_SERVICE, 'Processing bot upload request.');

    final contentType = request.headers['content-type'];
    if (contentType == null ||
        !contentType.toLowerCase().startsWith('multipart/form-data')) {
      throw BotUploadException('Content-Type multipart/form-data richiesto.');
    }

    final boundary = _extractBoundary(contentType);
    if (boundary == null || boundary.isEmpty) {
      throw BotUploadException('Boundary multipart non trovato.');
    }

    final transformer = MimeMultipartTransformer(boundary);
    final parts = await transformer.bind(request.read()).toList();

    if (parts.isEmpty) {
      throw BotUploadException('Nessun file trovato nella richiesta.');
    }

    File? uploadedFile;
    final tempDir = await Directory.systemTemp.createTemp('bot_upload_');
    try {
      for (final part in parts) {
        final formData = HttpMultipartFormData.parse(part);
        final name = formData.contentDisposition.parameters['name'];
        if (name != 'file') {
          // Ignora campi diversi dal file principale.
          await _drainStream(formData);
          continue;
        }

        final filename =
            formData.contentDisposition.parameters['filename'] ?? 'upload.zip';
        final bytes = await _collectBytes(formData);
        final filePath = p.join(tempDir.path, filename);
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        uploadedFile = file;
        break;
      }

      if (uploadedFile == null) {
        throw BotUploadException('Campo file non presente nella richiesta.');
      }

      final extractionDir = Directory(p.join(tempDir.path, 'extracted'));
      await extractionDir.create(recursive: true);

      await _extractUploadedAsset(uploadedFile, extractionDir);

      final manifestFile = await _findManifest(extractionDir);
      if (manifestFile == null) {
        throw BotUploadException('File Bot.json non trovato nell\'archivio.');
      }

      final manifest = await BotUtils.fetchBotDetails(manifestFile.path);
      _validateManifest(manifest);

      final botName = manifest['botName'] as String;
      final language = manifest['language'] as String;
      final description = manifest['description'] as String;
      final startCommand = manifest['startCommand'] as String;

      final botSourceDir = manifestFile.parent;
      final targetDir =
          Directory(p.join('localbots', language, botName));

      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await targetDir.create(recursive: true);

      await _copyDirectory(botSourceDir, targetDir);

      final localManifestPath = p.join(targetDir.path, 'Bot.json');
      final bot = Bot(
        botName: botName,
        description: description,
        startCommand: startCommand,
        sourcePath: localManifestPath,
        language: language,
        origin: 'Locali',
      );

      await _botDatabase.insertOrUpdateLocalBot(bot);

      logger.info(LOGS.BOT_SERVICE,
          LOGS.BOT_UPLOADED.replaceFirst('%s', '$botName ($language)'));

      return bot;
    } on BotUploadException {
      rethrow;
    } catch (e) {
      logger.error(LOGS.BOT_SERVICE, 'Errore durante l\'upload: $e');
      throw BotUploadException('Errore interno durante l\'upload del bot.',
          statusCode: 500);
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {
        logger.warn(LOGS.BOT_SERVICE, 'Impossibile cancellare la cartella temporanea.');
      }
    }
  }

  String? _extractBoundary(String contentType) {
    final mimeType = HeaderValue.parse(contentType);
    return mimeType.parameters['boundary'];
  }

  Future<List<int>> _collectBytes(HttpMultipartFormData data) async {
    final buffer = <int>[];
    await for (final chunk in data) {
      buffer.addAll(chunk);
    }
    return buffer;
  }

  Future<void> _drainStream(Stream<List<int>> stream) async {
    await for (final _ in stream) {
      // discard
    }
  }

  Future<void> _extractUploadedAsset(File uploadedFile, Directory destination) async {
    if (uploadedFile.path.toLowerCase().endsWith('.zip')) {
      await ZipUtils.unzipFile(uploadedFile.path, destination.path);
    } else {
      // If the user uploaded a single manifest or loose files, move them as-is.
      final targetPath = p.join(destination.path, p.basename(uploadedFile.path));
      await uploadedFile.copy(targetPath);
    }
  }

  Future<File?> _findManifest(Directory root) async {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File &&
          p.basename(entity.path).toLowerCase() == 'bot.json') {
        return entity;
      }
    }
    return null;
  }

  void _validateManifest(Map<String, dynamic> manifest) {
    const requiredKeys = ['botName', 'language', 'description', 'startCommand'];
    for (final key in requiredKeys) {
      if (!manifest.containsKey(key) || manifest[key] == null) {
        throw BotUploadException('Manifest mancante del campo obbligatorio: $key');
      }
      if (manifest[key] is String && (manifest[key] as String).trim().isEmpty) {
        throw BotUploadException('Il campo "$key" nel manifest non può essere vuoto.');
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }

    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }
}
