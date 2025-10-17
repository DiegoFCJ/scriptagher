import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/bot.dart';
import '../../services/bot_get_service.dart';
import '../../services/bot_upload_service.dart';
import '../components/bot_card_component.dart';
import 'bot_detail_view.dart';

class BotList extends StatefulWidget {
  @override
  _BotListState createState() => _BotListState();
}

class _BotListState extends State<BotList> {
  late Future<Map<String, List<Bot>>> _remoteBots;
  late Future<List<Bot>> _localBots;

  final BotGetService _botGetService = BotGetService();
  final BotUploadService _botUploadService = BotUploadService();

  @override
  void initState() {
    super.initState();
    _remoteBots = _botGetService.fetchBots();
    _localBots = _botGetService.fetchLocalBotsFlat();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lista dei Bot')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadOptions,
        child: Icon(Icons.upload_file),
        tooltip: 'Importa bot locale',
      ),
      body: FutureBuilder<Map<String, List<Bot>>>(
        future: _remoteBots,
        builder: (context, remoteSnapshot) {
          return FutureBuilder<List<Bot>>(
            future: _localBots,
            builder: (context, localSnapshot) {
              if (remoteSnapshot.connectionState == ConnectionState.waiting ||
                  localSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (remoteSnapshot.hasError) {
                return Center(
                    child: Text('Errore remoto: ${remoteSnapshot.error}'));
              }

              if (localSnapshot.hasError) {
                return Center(
                    child: Text('Errore locale: ${localSnapshot.error}'));
              }

              final remoteData = remoteSnapshot.data ?? {};
              final localData = localSnapshot.data ?? [];

              return ListView(
                children: [
                  ExpansionTile(
                    title: Text('Local Bots'),
                    children: localData.map((bot) {
                      return BotCard(
                        bot: bot,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BotDetailView(bot: bot),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                  ExpansionTile(
                    title: Text('Remote Bots'),
                    children: remoteData.entries.map((entry) {
                      final language = entry.key;
                      final bots = entry.value;

                      return ExpansionTile(
                        title: Text(language),
                        children: bots.map((bot) {
                          return BotCard(
                            bot: bot,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BotDetailView(bot: bot),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.archive_outlined),
                title: Text('Carica archivio ZIP'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickZipAndUpload();
                },
              ),
              ListTile(
                leading: Icon(Icons.folder_open),
                title: Text('Carica cartella'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickDirectoryAndUpload();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickZipAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final file = File(path);
    await _uploadBot(() => _botUploadService.uploadZip(file));
  }

  Future<void> _pickDirectoryAndUpload() async {
    final directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath == null) return;
    await _uploadBot(() => _botUploadService.uploadDirectory(directoryPath));
  }

  Future<void> _uploadBot(Future<Bot> Function() uploader) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Bot? uploadedBot;
    Object? error;

    try {
      uploadedBot = await uploader();
    } catch (e) {
      error = e;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il caricamento: $error')),
      );
      return;
    }

    if (uploadedBot != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Bot "${uploadedBot.botName}" importato con successo.')),
      );
      setState(() {
        _localBots = _botGetService.fetchLocalBotsFlat();
      });
    }
  }
}
