import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:scriptagher/shared/constants/APIS.dart';
import 'package:scriptagher/shared/custom_logger.dart';
import 'package:scriptagher/shared/utils/BotUtils.dart';
import 'package:scriptagher/shared/utils/ZipUtils.dart';
import '../db/bot_database.dart';
import '../models/bot.dart';

class BotUploadService {
  BotUploadService(this.botDatabase);

  final BotDatabase botDatabase;
  final CustomLogger logger = CustomLogger();

  /// Processes an uploaded bot archive and stores it locally.
  Future<Bot> importBotArchive(File uploadedFile) async {
    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('bot_upload_');
      final normalizedFile =
          await _normalizeUploadedFile(uploadedFile, tempDir: tempDir);
      final isZip = await _isZipArchive(normalizedFile);
      if (!isZip) {
        throw const FormatException('Unsupported file type. Please upload a ZIP archive.');
      }

      final extractionDir = Directory(p.join(tempDir.path, 'extracted'));
      await extractionDir.create(recursive: true);
      await ZipUtils.unzipFile(normalizedFile.path, extractionDir.path);

      final manifestFile = await _findManifestFile(extractionDir);
      if (manifestFile == null) {
        throw const FormatException('Bot.json manifest not found in the uploaded archive.');
      }

      final manifest = await BotUtils.fetchBotDetails(manifestFile.path);
      final bot = _mapManifestToBot(manifest, manifestFile);

      await _persistBotFiles(manifestFile.parent, bot);
      await botDatabase.insertOrUpdateLocalBot(bot);

      logger.info('BotUploadService',
          'Imported bot ${bot.botName} (${bot.language}) successfully.');
      return bot;
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      if (await uploadedFile.exists()) {
        await uploadedFile.delete();
      }
    }
  }

  Future<File> _normalizeUploadedFile(File uploadedFile,
      {required Directory tempDir}) async {
    if (!await uploadedFile.exists()) {
      throw FileSystemException('Uploaded file not found', uploadedFile.path);
    }

    if (uploadedFile.parent.path == tempDir.path) {
      return uploadedFile;
    }

    final destination =
        File(p.join(tempDir.path, p.basename(uploadedFile.path)));
    await uploadedFile.copy(destination.path);
    return destination;
  }

  Future<bool> _isZipArchive(File file) async {
    if (!await file.exists()) {
      return false;
    }

    final raf = await file.open();
    try {
      final header = await raf.read(4);
      if (header.length < 4) return false;
      return header[0] == 0x50 &&
          header[1] == 0x4b &&
          (header[2] == 0x03 || header[2] == 0x05 || header[2] == 0x07) &&
          (header[3] == 0x04 || header[3] == 0x06 || header[3] == 0x08);
    } finally {
      await raf.close();
    }
  }

  Future<File?> _findManifestFile(Directory extractionDir) async {
    final expectedName = APIS.BOT_FILE_CONFIG.toLowerCase();
    await for (final entity in extractionDir.list(recursive: true)) {
      if (entity is File &&
          p.basename(entity.path).toLowerCase() == expectedName) {
        return entity;
      }
    }
    return null;
  }

  Bot _mapManifestToBot(Map<String, dynamic> manifest, File manifestFile) {
    final botName = _requireString(manifest, 'botName');
    final language = _requireString(manifest, 'language');

    final description = (manifest['description'] as String?)?.trim() ?? '';
    final startCommand =
        (manifest['startCommand'] ?? manifest['entrypoint']) as String? ?? '';
    final compat = BotCompat.fromManifest(manifest['compat']);

    final destinationManifestPath = p.join(
      APIS.BOT_DIR_DATA_LOCAL,
      language,
      botName,
      APIS.BOT_FILE_CONFIG,
    );

    return Bot(
      botName: botName,
      description: description,
      startCommand: startCommand,
      sourcePath: destinationManifestPath,
      language: language,
      compat: compat,
      permissions:
          (manifest['permissions'] as List?)?.whereType<String>().toList() ??
              const <String>[],
      archiveSha256: manifest['archiveSha256']?.toString(),
      author: (manifest['author'] as String?)?.trim() ?? 'Sconosciuto',
      version: (manifest['version'] as String?)?.trim() ?? '0.0.0',
      platformCompatibility: _derivePlatformCompatibility(compat),
    );
  }

  List<String> _derivePlatformCompatibility(BotCompat compat) {
    final platforms = <String>{};
    if (compat.desktopRuntimes.isNotEmpty) {
      platforms.add('desktop');
    }
    if (compat.browserSupported == true) {
      platforms.add('browser');
    }
    return platforms.toList(growable: false);
  }

  Future<void> _persistBotFiles(Directory sourceDir, Bot bot) async {
    final destinationDir = Directory(p.join(
      APIS.BOT_DIR_DATA_LOCAL,
      bot.language,
      bot.botName,
    ));

    if (await destinationDir.exists()) {
      await destinationDir.delete(recursive: true);
    }
    await destinationDir.create(recursive: true);

    await _copyDirectory(sourceDir, destinationDir);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(followLinks: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is File) {
        await File(newPath).create(recursive: true);
        await entity.copy(newPath);
      } else if (entity is Directory) {
        final newDir = Directory(newPath);
        await newDir.create(recursive: true);
        await _copyDirectory(entity, newDir);
      }
    }
  }

  String _requireString(Map<String, dynamic> manifest, String key) {
    final value = manifest[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Manifest is missing required field "$key".');
  }
}
