import 'dart:io';
import 'package:archive/archive.dart';  // Add this package to your pubspec.yaml

class ZipUtils {
  /// Unzips a ZIP file to the specified directory.
  ///
  /// [zipFilePath] - The path to the ZIP file to extract.
  /// [destinationDirPath] - The path to the directory where the contents will be extracted.
  ///
  /// Throws [IOException] if there is an error during extraction.
  static Future<void> unzipFile(String zipFilePath, String destinationDirPath) async {
    File zipFile = File(zipFilePath);
    Directory destinationDir = Directory(destinationDirPath);

    if (!await zipFile.exists()) {
      throw FileSystemException("ZIP file not found at $zipFilePath");
    }

    if (!await destinationDir.exists()) {
      await destinationDir.create(recursive: true);
    }

    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filePath = '${destinationDir.path}/${file.name}';
        if (file.isFile) {
          final outputFile = File(filePath);
          await outputFile.create(recursive: true);
          await outputFile.writeAsBytes(file.content as List<int>);
        } else {
          final directory = Directory(filePath);
          await directory.create(recursive: true);
        }
      }

      print('Extraction completed successfully.');
    } catch (e) {
      print('Error while unzipping: $e');
      rethrow;
    }
  }

  /// Deletes the ZIP file if it was successfully unzipped.
  ///
  /// [zipFilePath] - The path to the ZIP file to delete.
  /// [extractionSuccessful] - Whether the extraction was successful.
  static Future<void> deleteZipIfUnzipped(String zipFilePath, bool extractionSuccessful) async {
    if (extractionSuccessful) {
      final zipFile = File(zipFilePath);
      if (await zipFile.exists()) {
        try {
          await zipFile.delete();
          print('ZIP file deleted successfully.');
        } catch (e) {
          print('Error deleting ZIP file: $e');
        }
      } else {
        print('ZIP file not found at: $zipFilePath');
      }
    }
  }

  /// Extracts a file from the ZIP entry to the destination directory.
  ///
  /// This functionality is handled as part of the `unzipFile` method in Dart,
  /// since the `archive` package processes files and directories efficiently.
  static void getExtractedFile() {
    throw UnimplementedError(
        'getExtractedFile functionality is integrated in unzipFile.');
  }
}